$b="http://localhost:4000/api"; $ErrorActionPreference="Stop"
function J($o){ $o | ConvertTo-Json -Depth 6 }
function Code($sb){ try { & $sb | Out-Null; "200" } catch { [string]$_.Exception.Response.StatusCode.value__ } }
$login = Invoke-RestMethod -Method Post "$b/auth/login" -ContentType "application/json" -Body (J @{email="alex.rivera@email.com";password="therapy-pal";role="patient"})
$h=@{Authorization="Bearer $($login.token)"}
"USER: $($login.user.name) / clinician: $($login.user.clinician.name)"
$d=(Get-Date).ToString("yyyy-MM-dd"); $t=(Get-Date).ToString("HH:mm"); $q="?day=$d&time=$t"
$today = Invoke-RestMethod "$b/patient/today$q" -Headers $h
"TODAY: taken=$($today.taken) total=$($today.total) next=$($today.next.label) $($today.next.slot)"
$today.doses | ForEach-Object { "   $($_.slot) $($_.label) -> $($_.status)" }
$ad = Invoke-RestMethod "$b/patient/adherence$q" -Headers $h
"ADHERENCE: rate=$($ad.rate) taken=$($ad.taken) missed=$($ad.missed) streak=$($ad.streak) weekly=$($ad.weekly -join ',')"
$n = Invoke-RestMethod "$b/notifications$q" -Headers $h
"NOTIFS: unread=$($n.unread) count=$($n.notifications.Count)"
$logs = Invoke-RestMethod "$b/patient/logs$q" -Headers $h
"LOGS: $($logs.logs.Count) entries"
$reg = Invoke-RestMethod "$b/patient/regimens" -Headers $h
"REGIMENS: $($reg.regimens.Count) ($(($reg.regimens | Where-Object active).Count) active)"
$due = $today.doses | Where-Object { $_.status -ne 'taken' } | Select-Object -First 1
if ($due) {
  $r = Invoke-RestMethod -Method Post "$b/patient/doses" -Headers $h -ContentType "application/json" -Body (J @{regimenId=$due.regimenId;slot=$due.slot;day=$d;time=$t})
  "LOG DOSE: ok=$($r.ok) slot=$($r.slot)"
  "LOG DOSE AGAIN (expect 409): " + (Code { Invoke-RestMethod -Method Post "$b/patient/doses" -Headers $h -ContentType "application/json" -Body (J @{regimenId=$due.regimenId;slot=$due.slot;day=$d;time=$t}) })
}
$new = Invoke-RestMethod -Method Post "$b/patient/regimens" -Headers $h -ContentType "application/json" -Body (J @{name="Test Item";strength="5 mg";type="medication";times=@("21:00","06:00");day=$d;time=$t})
"ADD REGIMEN: $($new.regimen.name) times=$($new.regimen.times -join ',')"
$pa = Invoke-RestMethod -Method Patch "$b/patient/regimens/$($new.regimen.id)" -Headers $h -ContentType "application/json" -Body (J @{active=$false})
"PAUSE: active=$($pa.regimen.active)"
$ct = Invoke-RestMethod -Method Patch "$b/auth/me" -Headers $h -ContentType "application/json" -Body (J @{phone="(415) 555-0199"})
"CONTACT UPDATE: $($ct.user.phone)"
$c = Invoke-RestMethod -Method Post "$b/auth/login" -ContentType "application/json" -Body (J @{email="s.carter@downtownclinic.org";password="therapy-pal";role="clinician"})
$ch=@{Authorization="Bearer $($c.token)"}
$p = Invoke-RestMethod "$b/clinician/patients$q" -Headers $ch
"PANEL: total=$($p.summary.total) avg=$($p.summary.avgAdherence) attention=$($p.summary.needsAttention)"
$p.patients | ForEach-Object { "   $($_.name): $($_.rate)% | $($_.regimen) | unread=$($_.unreadMessages)" }
$one = Invoke-RestMethod "$b/clinician/patients/$($p.patients[0].id)$q" -Headers $ch
"PATIENT DETAIL: $($one.patient.name) regimens=$($one.regimens.Count) history=$($one.history.Count)"
$an = Invoke-RestMethod "$b/clinician/analytics$q" -Headers $ch
"ANALYTICS: avg=$($an.avgAdherence) onTrack=$($an.onTrack)/$($an.patients) missed=$($an.missed) trend=$($an.trend -join ',')"
$th = Invoke-RestMethod "$b/messages/threads" -Headers $ch
"THREADS: $($th.threads.Count) unread=$($th.unread)"
$alexId = ($p.patients | Where-Object name -eq 'Alex Rivera').id
$conv = Invoke-RestMethod "$b/messages/threads/$alexId" -Headers $ch
"CONVERSATION: $($conv.messages.Count) messages with $($conv.with.name)"
$sent = Invoke-RestMethod -Method Post "$b/messages/threads/$alexId" -Headers $ch -ContentType "application/json" -Body (J @{text="Test reply from clinician"})
"SEND MESSAGE: from=$($sent.message.from)"
$an2 = Invoke-RestMethod -Method Post "$b/clinician/patients/$alexId/regimens" -Headers $ch -ContentType "application/json" -Body (J @{name="Assigned Test";strength="1 unit";type="therapy";times=@("10:00");day=$d;time=$t})
"ASSIGN REGIMEN: $($an2.regimen.name) by $($an2.regimen.prescriber)"
$n2 = Invoke-RestMethod "$b/notifications$q" -Headers $h
"PATIENT NOW SEES: unread=$($n2.unread), newest='$($n2.notifications[0].title)'"
"--- security checks"
"patient -> clinician route (expect 403): " + (Code { Invoke-RestMethod "$b/clinician/patients" -Headers $h })
"clinician -> patient route (expect 403): " + (Code { Invoke-RestMethod "$b/patient/regimens" -Headers $ch })
"no token (expect 401): " + (Code { Invoke-RestMethod "$b/patient/today" })
"wrong password (expect 401): " + (Code { Invoke-RestMethod -Method Post "$b/auth/login" -ContentType "application/json" -Body (J @{email="alex.rivera@email.com";password="wrong-pass"}) })
"wrong role (expect 403): " + (Code { Invoke-RestMethod -Method Post "$b/auth/login" -ContentType "application/json" -Body (J @{email="alex.rivera@email.com";password="therapy-pal";role="clinician"}) })
"other clinician's patient id bogus (expect 404): " + (Code { Invoke-RestMethod "$b/clinician/patients/not-a-real-id" -Headers $ch })
"bad register payload (expect 400): " + (Code { Invoke-RestMethod -Method Post "$b/auth/register" -ContentType "application/json" -Body (J @{role="patient";name="X";email="bad";password="1"}) })
"unknown route (expect 404): " + (Code { Invoke-RestMethod "$b/nope" })
"DONE"
