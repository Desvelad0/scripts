# Disables the stupid feature known as "aeroshake" which minimizes windows when shaking any window on Windows 10. 
# Note that this only disables the feature for the current user.
New-ItemProperty -path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name DisallowShaking -Value 1 -PropertyType "DWord"