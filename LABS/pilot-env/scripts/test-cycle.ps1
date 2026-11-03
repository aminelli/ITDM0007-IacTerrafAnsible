<#
.SYNOPSIS
  Full lifecycle test of the orders pilot: create -> test every service -> destroy.
.PARAMETER KeepRunning
  Do not destroy the environment at the end.
#>
param([switch]$KeepRunning)

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')

$script:Results = @()
function Step($name, [scriptblock]$check, [int]$timeoutSec = 0) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $last = $null
    do {
        try { $out = & $check; if ($out -ne $false) { $script:Results += [pscustomobject]@{Test = $name; Result = 'PASS'}; Write-Host "[PASS] $name $(if ($out -is [string]) { "($out)" })" -ForegroundColor Green; return } }
        catch { $last = $_.Exception.Message }
        if ($timeoutSec -gt 0) { Start-Sleep 5 }
    } while ((Get-Date) -lt $deadline)
    $script:Results += [pscustomobject]@{Test = $name; Result = 'FAIL'}
    Write-Host "[FAIL] $name $last" -ForegroundColor Red
}

function Mongo($js) {
    (docker exec pilot-mongodb mongosh --quiet -u root -p mongo_pwd --authenticationDatabase admin Ordini --eval $js) -join "`n"
}
function MongoNumber($expr) { [int](Mongo "print($expr)") }

Write-Host "== 1. Cleanup of any previous environment" -ForegroundColor Cyan
docker compose down -v --remove-orphans 2>&1 | Out-Null

Write-Host "== 2. Build and start" -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()
docker compose up -d --build 2>&1 | Select-Object -Last 5
Write-Host "Environment up in $([int]$sw.Elapsed.TotalSeconds)s"

Write-Host "== 3. Container tests" -ForegroundColor Cyan
foreach ($c in 'mysql', 'postgres', 'kafka', 'mongodb', 'connect', 'nifi', 'metabase') {
    Step "container pilot-$c healthy" { (docker inspect -f '{{.State.Health.Status}}' "pilot-$c") -eq 'healthy' } 300
}
foreach ($c in 'kafka-init', 'connect-init', 'nifi-init', 'metabase-init') {
    Step "init job pilot-$c exit 0" { (docker inspect -f '{{.State.Status}}/{{.State.ExitCode}}' "pilot-$c") -eq 'exited/0' } 300
}
foreach ($c in 'order-generator-mysql', 'order-generator-postgres') {
    Step "container pilot-$c running" { (docker inspect -f '{{.State.Status}}' "pilot-$c") -eq 'running' }
}

Write-Host "== 4. Source databases" -ForegroundColor Cyan
$mysqlCount = { [int](docker exec pilot-mysql mysql -uroot -pmysql_root_pwd -N -B -e "SELECT COUNT(*) FROM sales_mysql.orders" 2>$null) }
$pgCount = { [int](docker exec pilot-postgres psql -U pilot -d sales_postgres -At -c "SELECT COUNT(*) FROM sales_orders") }
Step "MySQL has orders" { (& $mysqlCount) -gt 0 } 60
Step "MySQL has order_items" { [int](docker exec pilot-mysql mysql -uroot -pmysql_root_pwd -N -B -e "SELECT COUNT(*) FROM sales_mysql.order_items" 2>$null) -gt 0 }
Step "PostgreSQL has sales_orders" { (& $pgCount) -gt 0 } 60
Step "PostgreSQL has sales_order_lines" { [int](docker exec pilot-postgres psql -U pilot -d sales_postgres -At -c "SELECT COUNT(*) FROM sales_order_lines") -gt 0 }
$m1 = & $mysqlCount; $p1 = & $pgCount; Start-Sleep 30; $m2 = & $mysqlCount; $p2 = & $pgCount
Step "MySQL generator rate ~1 order/5s (got $($m2 - $m1) in 30s)" { ($m2 - $m1) -ge 4 -and ($m2 - $m1) -le 8 }
Step "PostgreSQL generator rate ~1 order/6s (got $($p2 - $p1) in 30s)" { ($p2 - $p1) -ge 3 -and ($p2 - $p1) -le 7 }

Write-Host "== 5. Kafka Connect / Debezium" -ForegroundColor Cyan
Step "4 connectors RUNNING" {
    $names = Invoke-RestMethod http://localhost:8083/connectors
    if ($names.Count -ne 4) { return $false }
    foreach ($n in $names) {
        $s = Invoke-RestMethod "http://localhost:8083/connectors/$n/status"
        if ($s.connector.state -ne 'RUNNING' -or ($s.tasks | Where-Object state -ne 'RUNNING')) { return $false }
    }
    $true
} 60

Write-Host "== 6. Kafka topics" -ForegroundColor Cyan
foreach ($t in 'ordini-mysql', 'ordini-postgres') {
    Step "topic $t exists" { (docker exec pilot-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list) -contains $t }
    Step "topic $t carries order+items JSON" {
        $msg = docker exec pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic $t --from-beginning --max-messages 1 --timeout-ms 20000 2>$null
        $j = $msg | Select-Object -First 1 | ConvertFrom-Json
        $items = if ($t -eq 'ordini-mysql') { $j.items } else { $j.lines }
        $items.Count -gt 0
    }
}

Write-Host "== 7. MongoDB" -ForegroundColor Cyan
Step "collections exist" { (Mongo "print(db.getCollectionNames().sort().join(','))") -match 'data-ingest-ordini-mysql,data-ingest-ordini-postgres,ordini' }
Step "data-ingest-ordini-mysql populated with items" { (MongoNumber "db.getCollection('data-ingest-ordini-mysql').countDocuments({'items.0': {`$exists: true}})") -gt 0 } 60
Step "data-ingest-ordini-postgres populated with lines" { (MongoNumber "db.getCollection('data-ingest-ordini-postgres').countDocuments({'lines.0': {`$exists: true}})") -gt 0 } 60

Write-Host "== 8. NiFi ETL" -ForegroundColor Cyan
Step "NiFi flow: 14 processors RUNNING" {
    $root = Invoke-RestMethod http://localhost:8081/nifi-api/flow/process-groups/root
    $g = $root.processGroupFlow.flow.processGroups | Where-Object { $_.component.name -eq 'orders-etl' }
    $f = Invoke-RestMethod "http://localhost:8081/nifi-api/flow/process-groups/$($g.id)"
    ($f.processGroupFlow.flow.processors | Where-Object { $_.component.state -eq 'RUNNING' }).Count -eq 14
}
Step "ordini contains orders from both sources" { (MongoNumber "db.ordini.distinct('source_system').length") -eq 2 } 90
Step "ordini schema is uniform (0 non-conforming docs)" {
    (MongoNumber "db.ordini.countDocuments({`$or: [{source_system: {`$exists: false}}, {source_order_id: {`$exists: false}}, {order_date: {`$exists: false}}, {status: {`$nin: ['NEW','PAID','SHIPPED','CANCELLED']}}, {total_gross: {`$exists: false}}, {'customer.name': {`$exists: false}}, {'items.0.sku': {`$exists: false}}, {etl_processed_at: {`$exists: false}}, {lines: {`$exists: true}}, {order_status: {`$exists: true}}]})") -eq 0
}
Step "ingest backlog drained (<= 10 unprocessed)" {
    (MongoNumber "db.getCollection('data-ingest-ordini-mysql').countDocuments({etl_status: {`$exists: false}}) + db.getCollection('data-ingest-ordini-postgres').countDocuments({etl_status: {`$exists: false}})") -le 10
} 60
Step "end-to-end: ordini keeps growing (real-time)" {
    $a = MongoNumber "db.ordini.countDocuments()"; Start-Sleep 20; $b = MongoNumber "db.ordini.countDocuments()"; $b -gt $a
}

Write-Host "== 9. Metabase" -ForegroundColor Cyan
$mbToken = $null
Step "Metabase login" {
    $body = @{username = 'admin@example.com'; password = 'Pilot-Admin#2024'} | ConvertTo-Json
    $script:mbToken = (Invoke-RestMethod -Method Post -Uri http://localhost:3000/api/session -ContentType 'application/json' -Body $body).id; [bool]$script:mbToken
}
$h = @{'X-Metabase-Session' = $mbToken}
Step "2 dashboards present (BI + real-time)" {
    $d = Invoke-RestMethod -Headers $h http://localhost:3000/api/dashboard
    ($d | Where-Object { $_.name -in 'Orders BI Analysis', 'Orders Real-Time Monitor' }).Count -eq 2
}
$cards = Invoke-RestMethod -Headers $h http://localhost:3000/api/card
Step "15 Orders cards exist" { ($cards | Where-Object { $_.name -like 'Orders BI Analysis - *' -or $_.name -like 'Orders Real-Time Monitor - *' }).Count -eq 15 }
foreach ($c in ($cards | Where-Object { $_.name -like 'Orders BI Analysis - *' -or $_.name -like 'Orders Real-Time Monitor - *' })) {
    Step "card '$($c.name)' returns rows" {
        $r = Invoke-RestMethod -Method Post -Headers $h -Uri "http://localhost:3000/api/card/$($c.id)/query" -ContentType 'application/json' -Body '{}' -TimeoutSec 120
        if ($r.error) { throw $r.error }
        $r.data.rows.Count -gt 0
    } 30
}

Write-Host "== 10. Kafka client commands (documented CLI)" -ForegroundColor Cyan
Step "kafka-console-consumer on ordini-mysql from latest gets a new message" {
    $m = docker exec pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-mysql --max-messages 1 --timeout-ms 30000 2>$null
    [bool]$m
}

if (-not $KeepRunning) {
    Write-Host "== 11. Destroy" -ForegroundColor Cyan
    docker compose down -v --remove-orphans 2>&1 | Select-Object -Last 3
    Step "no containers left" { -not (docker ps -a --filter "name=pilot-" -q) }
    Step "no volumes left" { -not (docker volume ls -q --filter "name=orders-pilot") }
    Step "network removed" { -not (docker network ls -q --filter "name=orders-pilot-net") }
}

Write-Host "`n== SUMMARY" -ForegroundColor Cyan
$script:Results | Format-Table -AutoSize
$failed = ($script:Results | Where-Object Result -eq 'FAIL').Count
Write-Host "Passed: $(($script:Results | Where-Object Result -eq 'PASS').Count)  Failed: $failed"
exit $(if ($failed) { 1 } else { 0 })
