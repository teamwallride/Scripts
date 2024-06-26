<# This makes the computer beep.
1..10 | ForEach-Object {
    [console]::beep(3000, 500) # First number is pitch, second number is duration.
    Start-Sleep 30
}
#>

# This is cooler, it counts.
Add-Type -AssemblyName System.Speech
$synth = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
1..10 | ForEach-Object {
    $synth.Speak($_)
    Start-Sleep 30
    if ($_ -eq 10) {
        $synth.Speak("Stretching complete. You are awesome.")
    }
}