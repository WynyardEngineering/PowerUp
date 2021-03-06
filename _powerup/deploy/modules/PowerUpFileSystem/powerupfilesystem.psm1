function Execute-Command($Command, $CommandName) {
    $currentRetry = 0;
    $success = $false;
    do {
        try
        {
            & $Command;
            $success = $true;
            Write-Output "Successfully executed [$CommandName] command. Number of entries: $currentRetry";
        }
        catch [System.Exception]
        {
            $message = 'Exception occurred while trying to execute [$CommandName] command:' + $_.Exception.ToString();
            Write-Output $message;
            if ($currentRetry -gt 5) {
                $message = "Can not execute [$CommandName] command. The error: " + $_.Exception.ToString();
                throw $message;
            } else {
                Write-Output "Sleeping before $currentRetry retry of [$CommandName] command";
                Start-Sleep -s 1;
            }
            $currentRetry = $currentRetry + 1;
        }
    } while (!$success);
}

function Ensure-Directory([string]$directory)
{
    if (!(Test-Path $directory -PathType Container))
    {
        Write-Output "Creating folder $directory"
        New-Item $directory -type directory | out-null
    }
}

function ReplaceDirectory([string]$sourceDirectory, [string]$destinationDirectory)
{
    if (Test-Path $destinationDirectory -PathType Container)
    {
        Write-Output "Removing folder"
        Remove-Item $destinationDirectory -recurse -force
    }
    Write-Output "Copying files"
    Copy-Item $sourceDirectory\ -destination $destinationDirectory\ -container:$false -recurse -force
}

function Get-IsEmptyDirectory([string]$directory) {
    return !([bool](Get-ChildItem $directory\* -Force))
}

function Remove-Directory([string]$directory)
{
    if (Test-Path $directory -PathType Container)
    {
        Write-Output "Removing folder $directory"

        try {
            Remove-Item $directory -recurse -force
        }
        catch {
            Write-Output "Failed to remove directory $directory, will sleep for 5 and try again"
            Start-Sleep -s 5;

            if (Test-Path $directory -PathType Container)
            {
                Remove-Item $directory -recurse -force
            }
        }
    }
}

function copy-directory([string]$sourceDirectory, [string]$destinationDirectory, $onlyNewer, $preserveExisting, [string]$excludeFileMask)
{
    Write-Output "Copying newer files from $sourceDirectory to $destinationDirectory"
    $robocopyExe = Join-Path (get-item env:\windir).value system32\robocopy.exe

    if ($preserveExisting)
    {
        $output = & "$robocopyExe" $sourceDirectory $destinationDirectory /E /np /njh /nfl /ns /nc /xo /xn /xc /xf $excludeFileMask
    }
    elseif ($onlyNewer)
    {
        $output = & "$robocopyExe" $sourceDirectory $destinationDirectory /E /np /njh /nfl /ns /nc /xo /xf $excludeFileMask
    }
    else
    {
        $output = & "$robocopyExe" $sourceDirectory $destinationDirectory /E /np /njh /nfl /ns /nc /xf $excludeFileMask
    }

    if ($lastexitcode -lt 8)
    {
        cmd /c #reset the lasterrorcode strangely set by robocopy to be non-0
    }
    else
    {
        throw "Robocopy failed to mirror to $destinationDirectory. Exited with exit code $lastexitcode"
    }
}

function Copy-MirroredDirectory([string]$sourceDirectory, [string]$destinationDirectory, $excludedPaths)
{
    Write-Output "Mirroring $sourceDirectory to $destinationDirectory"
    $robocopyExe = Join-Path (get-item env:\windir).value system32\robocopy.exe

    if($excludedPaths)
    {
        $dirs = $excludedPaths -join " "
        $output = & "$robocopyExe" $sourceDirectory $destinationDirectory /E /np /njh /nfl /ns /nc /mir /XD $dirs
    }
    else
    {
        $output = & "$robocopyExe" $sourceDirectory $destinationDirectory  /E /np /njh /nfl /ns /nc /mir
    }

    if ($lastexitcode -lt 8)
    {
        cmd /c #reset the lasterrorcode strangely set by robocopy to be non-0
    }
    else
    {
        throw "Robocopy failed to mirror to $destinationDirectory. Exited with exit code $lastexitcode"
    }
}

function RobocopyFile {
    param (
        [string]$sourceDirectory,
        [string]$destinationDirectory,
        [string]$filename,
        [bool]$quiet = $True
    )

    #Robocopy seems fussy that dirs end in a trailing slash when copying files
    if (!($sourceDirectory.EndsWith("\"))){
      $sourceDirectory = $sourceDirectory + "\"
    }

    if (!($destinationDirectory.EndsWith("\"))){
      $destinationDirectory = $destinationDirectory + "\"
    }

    Write-Output "Robocopying $filename from $sourceDirectory to $destinationDirectory"
    $robocopyExe = Join-Path (get-item env:\windir).value system32\robocopy.exe

    if ($quiet) {
        $output = & "$robocopyExe" "$sourceDirectory" "$destinationDirectory" "$filename"
    } else {
        & "$robocopyExe" "$sourceDirectory" "$destinationDirectory" "$filename"
    }

    if ($lastexitcode -lt 8)
    {
        cmd /c #reset the lasterrorcode strangely set by robocopy to be non-0
    }
    else
    {
        throw "Robocopy failed to copy to $filename. Exited with exit code $lastexitcode"
    }
}

function New-Shortcut ( [string]$targetPath, [string]$fullShortcutPath, [string] $icon = $null, [string] $arguments = $null){
    Write-Output "Creating shortcut $fullShortcutPath targeting path $targetPath"

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($fullShortcutPath)
    $Shortcut.TargetPath = $targetPath
    if ($icon) {
        $Shortcut.IconLocation = $icon;
    }
    if ($arguments) {
        $Shortcut.Arguments = $arguments;
    }

    $Shortcut.Save()
}

function New-DesktopShortcut ( [string]$targetPath , [string]$shortcutName, [string] $icon = $null ){
    New-Shortcut $targetPath "$env:USERPROFILE\Desktop\$shortcutName" $icon
}

function Remove-DesktopShortcut ([string]$shortcutName) {
    $fileName = "$env:USERPROFILE\Desktop\$shortcutName"
    if (Test-Path $fileName) {
        Remove-Item $fileName -force
    }
}

function Write-FileToConsole([string]$fileName)
{
    $line=""

    if ([System.IO.File]::Exists($fileName))
    {
        $streamReader=new-object System.IO.StreamReader($fileName)
        $line=$streamReader.ReadLine()
        while ($line -ne $null)
        {
            Write-Output $line
            $line=$streamReader.ReadLine()
        }
        $streamReader.close()
    }
    else
    {
       Write-Output "Source file ($fileName) does not exist."
    }
}

function Invoke-Executable
{
    param(
        [string]$exe,
        [Array]$params = $null,
        [bool]$ignoreFailure=$false
    )

    Write-ColoredOutput "Running $exe $params" -foregroundcolor "green"
    $Process = Start-Process $exe -Wait -PassThru -NoNewWindow -ArgumentList $params

    if ($ignoreFailure) {
      if ($Process.ExitCode -gt 0) {
        cmd /c
        Write-ColoredOutput "$exe failed, but ignoring failure" -foregroundcolor "yellow"
      }
      return
    }

    if ($Process.ExitCode -gt 0) {
        throw "$exe $params had non-zero exit code"
    }
}
 
Set-Alias RobocopyDirectory Copy-Directory

Export-ModuleMember -function '*'