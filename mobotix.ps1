#!/usr/bin/pwsh

# Log files
$LogSnmp = '/data/snmplog.txt'
$LogScript = '\data\scriptlog.txt'
# List of IPs
$IPFILE='\data\cam-list.txt'
# Configuration file
$CONFFILE='\data\config.txt'

Function LogMessage
{
	param($msg, $lvl)

	$date = Get-Date
	Write-Host "`n$date : $lvl - $msg"
	Add-Content $LogScript "`n$date : $lvl - $msg"
}

function Get-SnmpValues 
{
	LogMessage "Script started" "Info"

	# files existence test
	if(-not (Test-Path $IPFILE -PathType Leaf)){
		$Msg = "Missing file $IPFILE"
		Write-Host $Msg
		LogMessage $Msg "Error"
	}

	if(-not (Test-Path $CONFFILE -PathType Leaf)){
		$Msg = "Missing file $CONFFILE"
		Write-Host $Msg
		LogMessage $Msg "Error"
	}

	# import of configuration csv file in format [parameter;oid;threshold_operator;threshold_value] where threshold_operator can be '<','>','='
	try 
	{
		$config = Import-Csv -Path $CONFFILE -Header "parameter","oid","threshold_operator","threshold_value" -Delimiter ';'
	}
	catch 
	{
		$ErrorMessage = $_.Exception.Message
		Write-Host "Import CSV failed! $ErrorMessage"
		$ErrorMessage | Out-File $LogSnmp
	}

	#result hash table of IP's and parameter values of error state parameters
	$ht_errorlist = @{}
	# hash table of pair [parameter name, parameter oid]
	$ht_oids = @{}
	# hash table of pair [parameter name, parameter threshold operator]
	$ht_threshold_operators = @{}
	# hash table of pair [parameter name, parameter threshold value]
	$ht_threshold_values = @{}

	#save data from config file to hash tables
	foreach($row in $config)
	{
	#	Write-Host $row.parameter $row.oid
		$ht_oids[$row.parameter] = $row.oid
		$ht_threshold_operators[$row.parameter] = $row.threshold_operator
		$ht_threshold_values[$row.parameter] = $row.threshold_value
	}

	Write-Host 'DEBUG: ht_oids'
	$ht_oids | format-table

	Write-Host 'DEBUG: ht_threshold_operators '
	$ht_threshold_operators  | format-table

	Write-Host 'DEBUG: ht_threshold_values '
	$ht_threshold_values  | format-table

	# results array (each array object is hash table which contains results of one camera
	$AllResults = @()
	$results = @{}

	$HTMLoutput += '<!DOCTYPE html>
	<html>
	<head>
	<meta charset="UTF-8">
	<style>
	table, th, td {
	border: 1px solid black;
	border-collapse: collapse;
	}
	td.mx-ng-check {background-color: red;}
	</style>
	</head>
	<body>

	<h1>Mobotix monitoring</h1>

	<table>
	<tr style="background-color:#007EC5; color:white">
		<th>IP</th>
		
	'

	#generate table header
	foreach($row in $ht_oids.Keys)
	{
		$HTMLoutput += '<th>'+$row+'</th>'
	}
	$HTMLoutput += '</tr>'

	$scanStartTime=Get-Date -Format "dd.MM.yyyy HH:mm:ss"

	foreach($IP in Get-Content $IPFILE) {
		Write-Host 'DEBUG Cam IP: '+ $IP+
			$HTMLoutput += '<tr><td>'+$IP+'</td>'
			
			foreach($oid in $ht_oids.Keys) {
				Write-Host 'DEBUG: OID name: '$oid
				Write-Host 'DEBUG: OID: '$($ht_oids["$oid"])
				
				$value=	& snmpget -v 2c -OvQ -Lf $LogSnmp -r1 -t10 -c public $IP $($ht_oids["$oid"])
				#save result of this SNMP query to hash table together with OID name
				$results.Add($IP+'@'+$oid, $value)
				
				if($ht_threshold_operators.ContainsKey($oid) -and $ht_threshold_values.ContainsKey($oid)){
				Write-Host Plati $value $ht_threshold_operators.$oid $ht_threshold_values.$oid ???
					switch ($ht_threshold_operators.$oid) {
						"=" {if($value -eq $ht_threshold_values.$oid){
								$ht_errorlist.Add($IP,$value)
								Write-Host "="
								$HTMLoutput += '<td class="mx-ng-check">'
								}
								else{
									$HTMLoutput += '<td>'
									}
								break
								}
						"<" {if([int]$value -lt [int]$ht_threshold_values.$oid) {
								$ht_errorlist.Add($IP,$value)
								Write-Host "<"
								$HTMLoutput += '<td class="mx-ng-check">'
								}
								else{
									$HTMLoutput += '<td>'
									}
								break
								}
						">" {if([int]$value -gt [int]$ht_threshold_values.$oid) {
								$ht_errorlist.Add($IP,$value)
								Write-Host ">"
								$HTMLoutput += '<td class="mx-ng-check">'
								}
								else{
									$HTMLoutput += '<td>'
									}
								break
								}
						default {
								Write-Host No valid threshold operator
								$HTMLoutput += '<td>'
								LogMessage "No valid threshold operator" "Error"
								break
								}
					}
				}		
				
			$HTMLoutput += $value+'</td>'
			}
			
			Write-Host 'DEBUG: CAM with IP '+$IP+' results: '$results
			
		#add hashtable with results of this camera into AllResults array
		$AllResults += $results
		$HTMLoutput += '</tr>'
	}

	Write-Host 'DEBUG: All CAM Results: '$results$AllResults | format-table

	$scanEndTime=Get-Date -Format "dd.MM.yyyy HH:mm:ss"

	$HTMLoutput += '</table>'
	$HTMLoutput += 'Scan proveden: ' + $scanStartTime + ' - ' + $scanEndTime
	$HTMLoutput += '</body>
	</html>'

	Out-File -FilePath /usr/share/nginx/html/index.html -InputObject $HTMLoutput -Encoding utf8
}

while ($true)
{
	Get-SnmpValues
	Start-Sleep -Seconds 300
}