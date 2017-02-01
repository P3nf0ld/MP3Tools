<#

    Author: Pen Warner
    Version: 1.0
    Version History: 1.0 Initial Release

    Purpose: Batch convert .wav files to .mp3, edit mp3 tags

#>
Import-Module -Name MsOnline
Import-Module -Name Microsoft.Online.SharePoint.PowerShell -DisableNameChecking


$MaxThreads = 5
 
$RunspacePool = [RunspaceFactory ]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()

$uiHash = [hashtable]::Synchronized(@{})
$runspaceHash = [hashtable]::Synchronized(@{})
$jobs = [system.collections.arraylist]::Synchronized((New-Object -TypeName System.Collections.Arraylist))
$uiHash.jobFlag = $True
$newRunspace = [runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = 'STA'
$newRunspace.ThreadOptions = 'ReuseThread'          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable('uiHash',$uiHash)          
$newRunspace.SessionStateProxy.SetVariable('runspaceHash',$runspaceHash)     
$newRunspace.SessionStateProxy.SetVariable('jobs',$jobs)     
$psCmd = [PowerShell]::Create().AddScript({  
    Add-Type -AssemblyName PresentationFramework

    function Select-FolderDialog
    {
      param([string]$Title,[string]$Directory,[string]$Filter = 'All Files (*.*)|*.*')
  
      Add-Type -AssemblyName System.Windows.Forms
      $FolderBrowser = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
      $Show = $FolderBrowser.ShowDialog()
      If ($Show -eq 'OK')
      {
        return $FolderBrowser.SelectedPath
      }
      Else
      {
        Write-Warning -Message 'User aborted dialog.'
      }
    }
    function Select-FileDialog
    {
      param([Parameter(Mandatory = $True)][string]$Title,[string]$Directory,[string]$Filter = 'MP3 (*.mp3)| *.mp3')
      Add-Type -AssemblyName System.Windows.Forms
      $objForm = New-Object -TypeName System.Windows.Forms.OpenFileDialog
      $objForm.InitialDirectory = $Directory
      $objForm.Filter = $Filter
      $objForm.Title = $Title
      $Show = $objForm.ShowDialog()
      If ($Show -eq 'OK')
      {
        Return $objForm.FileName
      }
      Else
      {
        Write-Warning -Message 'User aborted dialog.'
      }
    }
    function Convert-Audio
    {
      [CmdletBinding()]
      Param(  
        [Parameter(Mandatory = $True,Position = 1)] $uiHash,
        [Parameter(Mandatory = $True,Position = 2)] [string]$inputFilePath,
        [Parameter(Mandatory = $True,Position = 3)] [string]$outputFilePath,
        [string]$ffmpegPath = 'C:\Users\penwa\Documents\GitHub\WavMp3Converter\ffmpeg.exe',      
        $rate = '192k', #The encoding bit rate
      $DeleteOriginal = $false)
        
      $uiHash.Host = $host
      $Runspace = [runspacefactory]::CreateRunspace()
      $Runspace.ApartmentState = 'STA'
      $Runspace.ThreadOptions = 'ReuseThread'
      $Runspace.Open()
      $Runspace.SessionStateProxy.SetVariable('uiHash',$uiHash) 
      $Runspace.SessionStateProxy.SetVariable('inputFilePath',$inputFilePath)
      $Runspace.SessionStateProxy.SetVariable('outputFilePath',$outputFilePath)
      $Runspace.SessionStateProxy.SetVariable('rate',$rate)
      $Runspace.SessionStateProxy.SetVariable('ffmpegPath',$ffmpegPath)

      $code = {
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Found file ' + (Get-ChildItem $inputFilePath).Name 
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $outfile = $outputFilePath.Split('\')
            $Outfilename = $outfile[$outfile.Count-1]
                  
            #$uiHash.outputBox.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) 
            $message = ' ▸ converting to ' + $Outfilename
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Yellow'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })      
        $arguments = " -i '" + $inputFilePath  + "' -id3v2_version 3 -f mp3 -ab " + $rate + " -ar 44100 '" + $outputFilePath + "' -y"        
        $Status = Invoke-Expression -Command "$ffmpegPath $arguments 2>&1"
        $t = $Status[$Status.Length-2].ToString() + ' ' + $Status[$Status.Length-1].ToString()
        $results += $t.Replace("`n",'')
        if ($results) 
        {
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $uiHash.progress.Value = $uiHash.progress.Value + (100/$uiHash.files.Count)
              $message = ' ▸▸ ' + $outputFilePath + ' ... Complete'
                  
              $Run = New-Object -TypeName System.Windows.Documents.Run
              $Run.Foreground = 'White'
              $Run.Text = $message
              $uiHash.outputBox.Inlines.Add($Run)
              $message = ' ▸▸ (' + ([math]::Round($uiHash.progress.Value,2)).ToString() + '% Overall)' 
                  
              $Run = New-Object -TypeName System.Windows.Documents.Run
              $Run.Foreground = 'Green'
              $Run.Text = $message
              $uiHash.outputBox.Inlines.Add($Run)
              $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak))
          }) 
          $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
              $uiHash.scrollviewer.ScrollToEnd()
          }) 
          if($uiHash.progress.Value -eq 100)
          {
            $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
                $message = 'Conversion Complete'
                $Run = New-Object -TypeName System.Windows.Documents.Run
                $Run.Foreground = 'White'
                $Run.Text = $message
                $uiHash.outputBox.Inlines.Add($Run)
                $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
            })
            $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
                $uiHash.scrollviewer.ScrollToEnd()
            }) 
          }   
          return $results
        }
        else 
        {
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = ' ▸▸ No File Found '
              $Run = New-Object -TypeName System.Windows.Documents.Run
              $Run.Foreground = 'Red'
              $Run.Text = $message
              $uiHash.outputBox.Inlines.Add($Run)
              $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
          })   
        }
      }
      $PSinstance = [powershell]::Create().AddScript($code)
      $PSinstance.RunspacePool = $RunspacePool
      $PSinstance.Runspace = $Runspace
      $jobs = $PSinstance.BeginInvoke()
    }
  
    #Build the GUI
    [xml]$xaml = @'
<Window
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
MinWidth="605"
Width ="800"
MinHeight="450"
Height="714"
Title="PensPlace - .wav to .mp3  batch converter and tag editor"
Topmost="True" Background="#FF838383" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
<Grid Margin="0,0,0,0">
<Grid.ColumnDefinitions>

<ColumnDefinition Width="*"/>
</Grid.ColumnDefinitions>
<Grid.RowDefinitions>
<RowDefinition Height="59"/>
<RowDefinition Height="328"/>
<RowDefinition MinHeight="150" />
<RowDefinition Height="37"/>
</Grid.RowDefinitions>

<ScrollViewer x:Name="scrollviewer" CanContentScroll="True" Margin="10,24,12,0" VerticalScrollBarVisibility="Visible" HorizontalScrollBarVisibility="Hidden" Grid.Row="2"  Background="#FF012456" Foreground="White">
<TextBlock x:Name="outputBox" TextWrapping="Wrap" Width="746" FontFamily="Consolas"/>
</ScrollViewer>
<StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Bottom" Grid.Row="3" Height="35" Width="222"/>
<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Grid.Row="3" Height="35" Width="92" Margin="0,0,10,0">
<Button x:Name="buttonCancel" MinWidth="80" Height="22" Margin="5,6,5,7" Content="Close" Width="87"/>
</StackPanel>
<TextBlock HorizontalAlignment="Left" Margin="10,5,0,0" TextWrapping="Wrap" Text="Output Window:" VerticalAlignment="Top" Width="150" Foreground="White" Height="19" Grid.Row="2"/>
<TabControl x:Name="tabControl" HorizontalAlignment="Left" Margin="11,2,0,0" Width="771" BorderBrush="White" RenderTransformOrigin="0.5,0.5" Grid.Row="1" Background="Gainsboro">

<TabItem x:Name="tabConvert" Header="Convert" Margin="-3,-2,0,0" FontSize="14">
<Grid Background="White">

<Grid.ColumnDefinitions>
<ColumnDefinition Width="10*"/>
<ColumnDefinition Width="37*"/>
</Grid.ColumnDefinitions>
<Grid.RowDefinitions>
<RowDefinition Height="6*"/>
<RowDefinition Height="60*"/>
<RowDefinition Height="40"/>
<RowDefinition Height="18"/>
<RowDefinition Height="40*"/>
<RowDefinition Height="79*"/>
<RowDefinition Height="52*"/>
</Grid.RowDefinitions>
<TextBlock x:Name="textBlock4" HorizontalAlignment="Left" Margin="10,2,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="595" Height="25" FontSize="18" Grid.ColumnSpan="2" Grid.Row="1"><Run Text="Batch "/><Run Text=".wav to .mp3 c"/><Run Text="onversion, "/><Run Text="please "/><Run Text="select input and output folders"/><Run Text="."/></TextBlock>
<TextBlock x:Name="textBlock5" HorizontalAlignment="Right" Margin="0,6,0,0" Grid.Row="2" TextWrapping="Wrap" Text="Input Folder:" VerticalAlignment="Top" RenderTransformOrigin="0.466,0.511" Width="129" Height="24" FontSize="14" TextAlignment="Right" Padding="0,0,10,0"/>
<TextBlock x:Name="textBlock5_Copy" HorizontalAlignment="Right" Margin="-2,7,0,0" Grid.Row="4" TextWrapping="Wrap" Text="Output Folder:" VerticalAlignment="Top" RenderTransformOrigin="0.466,0.511" Width="165" Height="23" FontSize="14" TextAlignment="Right" Padding="0,0,10,0"/>
<TextBox x:Name="txtBoxInputFolder" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="0,5,0,0" Grid.Row="2" TextWrapping="Wrap" VerticalAlignment="Top" Width="479" FontSize="14" Text="C:\Users\penwa\Music\Vinyl"/>
<TextBox x:Name="txtBoxOutputFolder" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="0,7,0,0" Grid.Row="4" TextWrapping="Wrap" VerticalAlignment="Top" Width="479" FontSize="14" Text="C:\Users\penwa\Music\Ouput"/>
<Button x:Name="butInput" Content="Browse" Grid.Column="1" HorizontalAlignment="Left" Margin="494,5,0,0" Grid.Row="2" VerticalAlignment="Top" Width="98" Height="23"/>
<Button x:Name="butOutput" Content="Browse" HorizontalAlignment="Left" Margin="494,7,0,0" Grid.Row="4" VerticalAlignment="Top" Width="98" Height="23" Grid.Column="1"/>
<Button x:Name="butConvert" Content="Convert" HorizontalAlignment="Left" Margin="494,20,0,0" Grid.Row="5" VerticalAlignment="Top" Width="98" Height="23" Grid.Column="1"/>
<TextBlock x:Name="textBlock5_Copy1" HorizontalAlignment="Right" Margin="0,23,227,0" Grid.Row="5" TextWrapping="Wrap" Text="Bitrate:" VerticalAlignment="Top" RenderTransformOrigin="0.466,0.511" Width="58" Height="23" FontSize="14" TextAlignment="Right" Padding="0,0,10,0" Grid.Column="1"/>
<CheckBox x:Name="checkIncludeSubFolders" Content="Include Sub Folders" Grid.Column="1" HorizontalAlignment="Left" Margin="338,0,0,0" Grid.Row="3" VerticalAlignment="Top" Height="18" Width="141"/>
<ComboBox x:Name="bitRate" Grid.Column="1" HorizontalAlignment="Left" Margin="375,20,0,0" Grid.Row="5" VerticalAlignment="Top" Width="104" Height="23">
<ComboBoxItem Content="128k"/>
<ComboBoxItem Content="192k"/>
<ComboBoxItem Content="320k" IsSelected="True"/>
</ComboBox>

<ProgressBar x:Name="progress" HorizontalAlignment="Left" Height="36" Margin="10,6,0,0" Grid.Row="6" VerticalAlignment="Top" Width="745" Grid.ColumnSpan="2"/>
<TextBlock Text="{Binding ElementName=progress, Path=Value, StringFormat={}{0:0}%}" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="196,16,361,16" Grid.Column="1" Grid.Row="6" Width="45" TextAlignment="Center" Height="20" Foreground="White" FontWeight="Bold" />

</Grid>
</TabItem>
<TabItem x:Name="tabTagEditor" Header="Tag Editor" Margin="1,-2,-1,0" FontSize="14">
<Grid Background="White" Height="296" VerticalAlignment="Top" Margin="0,0,0,-1">
<Grid.ColumnDefinitions>
<ColumnDefinition Width="139*"/>
<ColumnDefinition Width="626*"/>
</Grid.ColumnDefinitions>
<Grid.RowDefinitions>
<RowDefinition Height="38*"/>
<RowDefinition Height="30"/>
<RowDefinition Height="27*"/>
<RowDefinition Height="27*"/>
<RowDefinition Height="28*"/>
<RowDefinition Height="28*"/>
<RowDefinition Height="27*"/>
<RowDefinition Height="59*"/>
<RowDefinition Height="32"/>
</Grid.RowDefinitions>
<TextBlock x:Name="textBlock5_Copy2" HorizontalAlignment="Right" Margin="-7,11,17,0" TextWrapping="Wrap" Text="Select mp3 File:" VerticalAlignment="Top" RenderTransformOrigin="0.466,0.511" Width="129" Height="24" FontSize="14" TextAlignment="Right" Padding="0,0,10,0"/>
<Button x:Name="butSelectmp3" Content="Browse" HorizontalAlignment="Left" Margin="5,9,0,0" VerticalAlignment="Top" Width="98" Height="23" Grid.Column="1"/>
<Rectangle Fill="#FF838383" HorizontalAlignment="Left" Height="258" Grid.Row="1" Grid.RowSpan="8" VerticalAlignment="Top" Width="139"/>
<TextBlock x:Name="textBlock" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Artist Name:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
<TextBlock x:Name="textBlock_Copy" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="2" TextWrapping="Wrap" Text="Track Title:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
<TextBlock x:Name="textBlock_Copy1" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="3" TextWrapping="Wrap" Text="Album Title:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
<TextBox x:Name="textBoxArtistName" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="1" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
<TextBox x:Name="textBoxTrackTitle" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="2" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
<TextBox x:Name="textBoxAlbumTitle" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="3" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
<TextBlock x:Name="textBlock_Copy2" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="4" TextWrapping="Wrap" Text="Track Number:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
<TextBox x:Name="textBoxTrackNumber" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="4" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
<TextBlock x:Name="textBlock_Copy3" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="5" TextWrapping="Wrap" Text="Year:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
<TextBox x:Name="textBoxYear" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="5" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
<TextBlock x:Name="textBlock_Copy4" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="6" TextWrapping="Wrap" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"><Run Text="Genre"/><Run Text=":"/></TextBlock>
<TextBox x:Name="textBoxGenre" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="6" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
<Rectangle Fill="#FF838383" HorizontalAlignment="Left" Height="167" Grid.Row="1" Grid.RowSpan="6" VerticalAlignment="Top" Width="98" Grid.Column="1" Margin="307,0,0,0"/>
<TextBlock x:Name="textBlock_Copy5" HorizontalAlignment="Left" Margin="47,4,0,0" Grid.Row="7" TextWrapping="Wrap" Text="Comments:" VerticalAlignment="Top" Width="81" Foreground="White" TextAlignment="Right" Height="19" RenderTransformOrigin="0.506,1.053"/>
<TextBox x:Name="textBoxComments" Grid.Column="1" HorizontalAlignment="Left" Height="83" Margin="5,4,0,0" Grid.Row="7" TextWrapping="Wrap" VerticalAlignment="Top" Width="400" Grid.RowSpan="2"/>
<TextBlock x:Name="textBlock_Copy6" HorizontalAlignment="Left" Margin="318,4,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Album Art:" VerticalAlignment="Top" Width="81" Foreground="White" TextAlignment="Right" Height="19" Grid.Column="1"/>
<Image x:Name="imageTag" Grid.Column="1" HorizontalAlignment="Left" Height="200" Margin="416,0,0,0" Grid.RowSpan="7" VerticalAlignment="Top" Width="200
  " Grid.Row="1"/>
<Button x:Name="buttonSelectTagPic" Content="Select Image" Grid.Column="1" HorizontalAlignment="Left" Height="24" Margin="312,3,0,0" VerticalAlignment="Top" Width="89" IsEnabled="False" Grid.Row="2"/>
<Button x:Name="buttonSaveTags" Content="Save Tags" Grid.Column="1" HorizontalAlignment="Left" Margin="519,2,0,0" Grid.Row="8" VerticalAlignment="Top" Width="97" Height="26" IsEnabled="False"/>
<TextBlock x:Name="textMP3" Grid.Column="1" HorizontalAlignment="Left" Margin="125,12,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="491" Height="21"/>
<TextBox x:Name="textBoxBPM" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="312,3,0,0" Grid.Row="5" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" Background="#FF838383" Foreground="White" TextAlignment="Center"/>
<TextBlock x:Name="textBlock1" Grid.Column="1" HorizontalAlignment="Left" Margin="312,4,0,0" Grid.Row="4" TextWrapping="Wrap" Text="BPM" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold"/>
</Grid>
</TabItem>

</TabControl>
<Image x:Name="imgLogo" HorizontalAlignment="Left" Height="50" Margin="632,10,0,0" VerticalAlignment="Top" Width="150" Grid.RowSpan="2"/>
<Image x:Name="imgProdLogo" HorizontalAlignment="Left" Height="50" Margin="12,4,0,0" VerticalAlignment="Top" Width="300" RenderTransformOrigin="0.5,0.5"/>
</Grid>
</Window>
'@

    $reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml)
    $uiHash.Window = [Windows.Markup.XamlReader]::Load( $reader )

    #region Connect to Controls
    #interface controls
    $uiHash.scrollviewer = $uiHash.Window.FindName('scrollviewer')
    $uiHash.outputBox = $uiHash.Window.FindName('outputBox')
    $uiHash.imgLogo = $uiHash.Window.FindName('imgLogo')
    $uiHash.imgProdLogo = $uiHash.Window.FindName('imgProdLogo')
    $uiHash.buttonCancel = $uiHash.Window.FindName('buttonCancel')
    $uiHash.ffmpeg = 'C:\Users\penwa\Documents\GitHub\WavMp3Converter\ffmpeg.exe'
    
    #Tab Convert Controls
    $uiHash.txtBoxInputFolder = $uiHash.Window.FindName('txtBoxInputFolder')
    $uiHash.txtBoxOutputFolder = $uiHash.Window.FindName('txtBoxOutputFolder')
    $uiHash.bitRate = $uiHash.Window.FindName('bitRate')
    $uiHash.butInput = $uiHash.Window.FindName('butInput')
    $uiHash.checkIncludeSubFolders = $uiHash.Window.FindName('checkIncludeSubFolders')
    $uiHash.butOutput = $uiHash.Window.FindName('butOutput')
    $uiHash.butConvert = $uiHash.Window.FindName('butConvert')
    $uiHash.checkSubFolders = 'False'
    $uiHash.progress = $uiHash.Window.FindName('progress')

    #Tab Tag Editor Controls
    $uiHash.butSelectmp3 = $uiHash.Window.FindName('butSelectmp3')
    $uiHash.textBoxArtistName = $uiHash.Window.FindName('textBoxArtistName')
    $uiHash.textBoxTrackTitle = $uiHash.Window.FindName('textBoxTrackTitle')
    $uiHash.textBoxAlbumTitle = $uiHash.Window.FindName('textBoxAlbumTitle')
    $uiHash.textBoxTrackNumber = $uiHash.Window.FindName('textBoxTrackNumber')
    $uiHash.textBoxYear = $uiHash.Window.FindName('textBoxYear')
    $uiHash.textBoxGenre = $uiHash.Window.FindName('textBoxGenre')
    $uiHash.textBoxComments = $uiHash.Window.FindName('textBoxComments')
    $uiHash.imageTag = $uiHash.Window.FindName('imageTag')
    $uiHash.buttonSelectTagPic = $uiHash.Window.FindName('buttonSelectTagPic')
    $uiHash.buttonSaveTags = $uiHash.Window.FindName('buttonSaveTags')
    $uiHash.textMP3 = $uiHash.Window.FindName('textMP3')
    $uiHash.textBoxBPM = $uiHash.Window.FindName('textBoxBPM')
    
    #endregion
    
    $uiHash.imgCheck = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAK2SURBVEhLrZZRSJNRFMfPvd/WFoyECCMqGkOJHkwGPUQUktpWpKFBsKKHXkLqJXLLXiSIoCJm+VC
      xYEZv9aJprXLaEOnBemmFSAOjIAdKRQWtxrZvu91zv2u57Zv7cvvB2Dn/7+7c+5177zkjsBw3m2zWlNLBKHUDY3YCZBPKjLAFABIHBmFzLjOc8E1+FeN10J+AB7ZkTD4e8Dz3rJpYEpVPGTBl1Yt6ExVNsPp6644cwENCQKzWMAx+MMaOpryRUakIFPktsP
      Y1e4CSER58rZSMQ8BKCPGY9zt+quEPL6X67w1w5YzAC26WS0lZclnWnvZFQmhrE2DO0+Z3/52WUjBIECWzLXlmMk7RFxtareAIARvLmi9pJh7FjPkLtytOTSEsR+spnnNuryi4iSpwurEDuhrapZIPgayHiku0Ajxbm+H18SA01tbBwMxTqebDD42b4g2Vv
      iG2rFkPE0f6IdDqhVvRIega94Oay8qnhRA7Xbz+hezZuB3aHLukp4GrfnUsAI6aDdD5qBfuTD+WT/TBg0MZT6X083DW1sODgxfg2eFrsHezE4KuHvH5lU7CvkEvTMxF5cjlIZYbLVP8LXZKPw/cwMu7T4rNRBKZJBwY6oHo51nhl4MvfoHfA14VS3D77TCc
      CF8VOcbgnSO9hoNrsLhicjtqeK4OSaWI2LdPEPs+BwPTT2BqfkaqBiHkLrH5m9apinmeu7p7UQkUiJNqNZwFpFZNQr/Pjr8RtQibBdZzIVcHvm30HBpiAnwLbBb4AP1KYQxOpX1jMbT/Npzs2Mf3fMOTvIC4pLQyGOtPdUeuSE/2gyWs8re0UUruY8mVklF
    UXHmq+3lQ+gKRoqVgJ8JmwffknpSMEOI5bygMjuj/q5BY+lx1WHKxKvKh9sWmhDcULxE/56MKI4N4WsQPigD4Ay6Z60Dt1yihAAAAAElFTkSuQmCC'
    $uiHash.imgCross = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJsSURBVEhLpVa/axRBFJ6d3RCLg1hcEUiKFEI0IFhYBVLHQsEmoJDSxs4ipYWQP8AibeAKi0BAEM5
      CU6TIFUIqm6BgYZGDXGEwYMCD3Znn997N5nazb/fU++C73fnxvjfvvZnZi0wDyJgWWfvYRNG6IVrCc3E0QAP89sGPkffvIPJD+v8WIhzHr3wc/8aTmog5KbgDm3Ywb4ZPkvswONXEmgibn+CDIKPDW/sEkyauuo6wTaHxIsgJrmrAK0due+i4Ebr+G0jXI+
      vce34XByHnX9AYFXFKQO/SOHfHYiOAQBxvqeJJYmh319DqaugYg5aXjd/bw9JaoWcMaLWguS0NXr2a99lZcvv7lGUZZRcX5NfWxrleWaGs35cxd3RENDdXts3nGXOLC7upDnY6I/GcwUlRPKc7PKzYi4a1Lw1W/0YdhBiLFoWkfU08Gw7Jb2xU7EXD2h5H0
      NMGmaqTIhvEmVj8KUfwXRvMWetkgnhO3kWJVLsO5+fYdJehUcBwaMyAr6QJQIo+aZ6ZWkFLDIXXbJnIzhlHwLdiBbLPDw6MmZ8PPUCWlaPBGfDdrnpOBER9juCZ5v3qDOQMOddq4o6PK/ZMRLDNB62Nl7QyAYeHD1FRPB8rOnEnJ0QLC2XbnDMz9yQSONhR
      J7ATHCJtt7ATWXmNODLTZe38smuj8xsaN7k9LaCXRc7dhd5Xuezwwp+8pzzA7alB9JzFQ2sMhLV1PdR/JdL9OsjpwISH4C/NuIm8UXhHBplm4JpdhEFHE9LIBUV6bwfzEqTIdZD7HN9pvK7jL8sSJstHCWIDOURR9CGy9m2Upp+5vwpj/gAtCTbGZme2swA
    AAABJRU5ErkJggg=='  
      
    #region Images
    $iconbase64 = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKRSURBVEhLtZY9iFpBEMfnPUWinChBtLnCIhYphCBWFmKVawwknVemTJ+Qxm+FtClPCBYGSXXkAhZ
      3ET8gChYWsYqEgGgUHiZ4apSoKGZm396RxOepwfxg2f8M72Z2Z9edE+AGQqHQgUqleigIwtFyubTifEh+1BLqNs4Xi8XiLBKJfGd/oIBiAgqsVqufonyO4xZzrmeO42Q+n2Oe1UQrCeLxuBNX9hYlW+0O9HEcBwKBc9mUUfGZEY1GfTi9w3GbOXaDdurzeD
      w/isViRXb9tgO+8g8oN5VkIxjnQTAYzJBmCXjNP6HctSzrGOGZ3MUzaavJ4geqGNzr9YLdbmd6NpvBeDyGTqcD5XIZer0e8ytAC47h/Fjgq/+GhmJpKIHFYoFsNgs6nQ6MRiM4HA7QarWQTCbh8vKSf7kK7sIm0j1HfWPdJ5MJtFotqNfrUKlUIJVKgSiK4
      HQ6+RfK4Dc+kX5E3N6a0WgEkiSB2WzmHmUotognbuX2Tuj1ehgOh9xSBhNYaQc73RwqjcvlAoPBALVajXvXcijEYrGvJGR7FTpkm80G3W6XBTeZTKDRaCCXy0G1WuVfrYdK1OZ6LdPpFJrNJjQaDcjn85BIJLYKjkhUoo0JBoMBlEolNqgs/T49O5uhxdMO
      Lri9d7Ck5yK956jpyf0fnIr8DT+R7b2S8fv9H0VS1CxwUixsJpOBdDrNra3BkPNnJFgCvotjHHspFZ7rE4xZJ33dcAqFwhdsFj/xVt3nrn/lJfaCF1yvtkzsal5M8gblgezZmjmtHIO/4jbjj5ZJ4E4+u93u13jFqG3ek70byWDNH4XD4ffcvkbxv4orsFf
    coScXd3SEgx7FqydFYj8ivOeoT+m2yO6/AfgF/HH9HrIvlqYAAAAASUVORK5CYII='
    $iconBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage 
    $iconBitmap.BeginInit() 
    $iconBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($iconbase64) 
    $iconBitmap.EndInit() 
    $iconBitmap.Freeze() 

    $uiHash.Window.Icon = $iconBitmap
    
    $logobase64 = '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
      uct8prIhgrg7uhLBOJlfMdxn6XPejfnGQ5+H/7/kIAs+6lZCiX7mLLa5rhmgy5hf/yZmmeTVanDxL1fZ1I3Kd2EA+U8gvJqwSAwSM8nb+/6+AUlgmMjyddj5Fbv1uDHqza
      TJ+7cIyM/3/3/lK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla98
      5Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8hWA/wfdmhmZdymm9w
      AABAtta0JU+s7K/gB/2McAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHic7ZqBbeowEED/CIyQ
      ERiBERghI3QERugIjNARGIERGIEN/DkJ6x/3z2c7cVoqvSc9qU1sx+dL7Bj48wcAAAAAAAAAAGAZc0rpVPD4cHpYqnsI6mptG7reR9C+JpefK+Wlz+eHF+Pnw4NT9xj0e+
      6IPypXYx7UzhJkbGrIeO6cfp0a6iZn3G29lnsgl70Uyu4fx2+Vfnh1R8Xv3Vut3FU7pxXtLKElfuHqjMGo/N8L46vJZb0c7p9taPSzH9UdFf/S/M/mOreF7SxFx6+Pyzx0
      MuNq782l8Xv3zVelfpTDL9VO6VmVcf50jkfxzxvFX7r+2rbWXt87f1Dn7b05Mv/CMWgjyn+pfy30xH8fnP9J1b+qv89vlH/hVigzIv+f6m+5TmkdaMn/dYP8C9dCmbX51/
      WP6fX9pbYejqIl/lKZEfmXenr+9uZoIcr/3bTX2o8otpYya/Of853nlQ/VXm2fM4qW+JPpZ2ZU/nfpdZ312oryr+cQaad1Tym0xH8vlFmTf72u5Hvergc97S2lFr+O0a5L
      9lxpDx21mcftWIk9yv8uva6fwq1w7d749TNp31HX5P+s6u5V3Uvh+FZ48ct9eEyv87LXn5b9n5ev0rjpvth37ag9Yef0V7hVchPFfzZtRfvYnvzvTP/0Ob0fLK2FI2nd/9
      ae4xI9+Zdx13PtpM5F7WkO6XXPXxvLUfH35F/n2K5Vei206+0W1OK/BrGNWv/1OT3f6lx7xyIO6f81obb/95Dns7QvXRq/7tf8rKu9mPOt7S7BzrlZ6cdUufYW+bd9ys9H
      /r81/961BLuGleI/OmV74/DYpz5qn4utpeX9t8RW+ddjlD8bzvTmX9DruH2v+O749V6lld5+9fCO+bdl9HvdkvzrvdZP51+v7Xbe155X9KuHd82/YNfvUv5ra6S+3k/mX7
      /3nSvlp1+W/w/nHs7a94jWcfPWSi//clze02Zzrd2zX5po/d86fj2PRd91ZK4L+9XDqPgjbM56nhu7Xpby30LP938j45dy+nlu3dfl+aK3Xz28e/7lGb4FbdkYPO6p/LuK
      78q/nodaP9fJ7729/ephn/7NU711pxS/w2TtnKvrtXzPNQVt6TJz8n/DFl3jO+KfnvbErPvX2y8AAAAAAAAAAAAAAAAAAHhT5DtgRERERERERERERERERERERERERERERE
      RERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERMRf5l8JRU34asKYEQAAAuNta0JU+s7K/gB/8pwAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHic7deNceIwEAbQlJASXEJKcAmUkBIogRIogRJSAiVQQkqgA100oz
      02GpMfcA5yfjvzJkZny7I+yRwPD+rXVSllNur3lfyXXfJfdv3i/Ie3e24m7rt+a3u80XqsYxrfPLX713GsZxpLfdZh7ue6cf51rmo9d9cPrX0q3/7avv2Y5v+a2rT7x336
      6s/ftvZ9+xvr4DhTZtHnHH3lTu8h/0N3/e6K/OeqTXf/z+5Xun0/9zvof83/0PbImOaufn5N879rbdVLa8t5xL/He2Ns10Y/x26NxfqKPqfW2SX59/3ka/J4SnuO+Hxo6y
      Xvhxj3ql2f88/zsbtmTdxB/vs2b5FrHEd7bcv7KuYzf3fkd36ff+zF0s5ZpfZ6fr5Pru/mH/2+psz6/F/bfVetfWyfY/3H+at0TazbOH+V+olrL/6+u5P8Y98OaS5yLtty
      2jd9/jEv6ZH+5r8/0573TJ/zufbP8q/12K6JDPv8+/HE8b7Lf+qeefx95ef/Vt1J/vV4V07vwpiTTXu2eLdP7f9DOb0/+3k6l39u382Yf9/ntfnHXv9o/FfVHeX/1J79uc
      s/t79M5P/Y8o89/Vn+8a6JfOO4H9t38h/L6f8r1bGN99L8X8rpey3G0I9/m+bkkrmPQdwy/6G8/+2XfyvH/MXxpp0b8zGk43jvDunv2PUd7fU41semrZup/Mfy/r06nDkv
      7r9Ofa4mxjg1nvysMeaS+lp/YfzPZ8b0pbpx/reoIeUTv8+vmsMZ66N3zI/UQvM/tHmu2W/vaOzyV/+05L/skv+yS/7LLvkvu+bMHwAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAfsAfGxhsDCoqbTwAADIYaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9
      Ilc1TTBNcENlaGlIenJlU3pOVGN6a2M5ZCI/Pgo8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJBZG9iZSBYTVAgQ29yZSA1LjMtYzAxMS
      A2Ni4xNDU2NjEsIDIwMTIvMDIvMDYtMTQ6NTY6MjcgICAgICAgICI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYt
      c3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS
      4wLyI+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+QWRvYmUgRmlyZXdvcmtzIENTNiAoV2luZG93cyk8L3htcDpDcmVhdG9yVG9vbD4KICAgICAgICAgPHhtcDpDcmVh
      dGVEYXRlPjIwMTYtMDktMTBUMDQ6MTQ6MTFaPC94bXA6Q3JlYXRlRGF0ZT4KICAgICAgICAgPHhtcDpNb2RpZnlEYXRlPjIwMTctMDEtMTFUMDk6MTM6MjVaPC94bXA6TW
      9kaWZ5RGF0ZT4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmRjPSJodHRw
      Oi8vcHVybC5vcmcvZGMvZWxlbWVudHMvMS4xLyI+CiAgICAgICAgIDxkYzpmb3JtYXQ+aW1hZ2UvcG5nPC9kYzpmb3JtYXQ+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPg
      ogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAK
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIA
      ogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgIAo8P3hwYWNrZXQgZW5kPS
      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'
    $logoBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage
    $logoBitmap.BeginInit()
    $logoBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($logobase64)
    $logoBitmap.EndInit()
    $logoBitmap.Freeze()

    $uiHash.imgLogo.source = $logoBitmap
    
    $imageBse64 = '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
      7TudWlcg9U/NGY1R+hvmvOm4qB+tCh9pnV+vuZ/3FPEsvD/Nmnsnsxnn2uzNGanxuBhIg7qP/KmdZ6s+e/X4/o69dwyp3v5H+NxSx98pLalrh4/rdNZvq/yOV77NfWLUxqfk+N+3ctbpHPN7fskpV+WPJpnVFeVn68N1r/mxmFs/738z9qWeqo+Le18tGo+
      +TOV+6P1OrYlPh9l1db/mH5q3a5pG+4vH3J8a+Vn+V69tf338r92HtHa1kdKe/YuXc5Xcc5apOmzvVUan837kmYq7bW/XZPKWFfq21v5qkPLPWP7p+qms0UvV2Pby/L+M1h9lje2Fb2n/sL+D/1c+P/Zwv/P1mBr/7PrghBCCL2K9Bz9aevj6sPaG7WsnIn
      l32+Jyzv3mU9/HsjtPxa/s49+nttyVqe+84i6/oY+3X9/ZyPpfUJLbF75DL1Fr+i/P6vmM/VDQefheVzu0vgtQDzD9vwry6/v5ubKbzkrURnJ0mb8fF7zicrfpen3Dp5O5/Ktz+tdiNNuIl8Xytmm1/weKL6r0jsu/azvM4523dsb83+FtNfeeXSW9tr879
      67VI/erh3snvH7u4XV85TG98PS3PjsLM8x5Pc9zLVyWn15lDy28sDjebQY6h2rv1P1/B6DneX38vT+bmcxat3/TcUw11fv2fPv3q/83qr/3tION/ivNnn7V+ZzLMfTqZyWdj5Sm0pds9RnPX76JuBQ8f9QaZv89bHt84v6R+u6OOV/1CKN3+jr3v6N2k/2I
      Mpf+5ZIserT+L3sVDkt7XykptZf+eRzvfpwzf9a7Gr3kHJscn+65RuwKf/1vVGcz71eqnvtG5zWPcicdKYRY+TlzLXx0XqW/9KipGn5Rm/Kf1+Tt2lcX2r+T/nS6r/mqxqLD/Y/jl+fB2v7cNeUry3p/JtUn291thD9r/Wzlvm/v5K/Nd0rzP/qo/r9Xv6f
      gs+67vPtOl22f11JNyX57z7X5vUu1f/vl655PXyvOzc+j5X8usfQWM5cG39bsW738l99QM+8qZI//+5z9Jflazn/U/zz/Xdp3G/5s+s2nZ8xe7vWdn03k7ampaU9lPT7St5r5cy18belmOu5fFXasgp1k4/uS28x1jX5vw++f6XLZ/9tOj8bOJmPLXXv0/m
      zvfIN4b774ketXeuQVv60+J/le1ZvQ9zrbyrl1Oa/d1fL3unVpTH8F/35bb27/4s0zs2t8xAa9U7+a03I43wo//qe4tn1e0e9k//LVP8/ObX1G/1dDWk8q8N3hBBCCCGEEEII3V35vAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBD+A/ZgMOHZt7QzgAAKhdta0JU+s7K/gB/1PAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHic7X0ruOwo1vaSSCwSicQik
      UgkFhmJxCIjkVgkEhmJjYyMjI0smX9R+5zunp7p+dT/1Ihac+k+VXvXCbAu77suVObnfTaeANqzkS3G10Zgh6PDAnBdxQVrAN+FfsPzYh3ggQoQAbYKG9CeJMF33ZPZsYTB8c18c/zxQ28AlZvdQSvVcTO2vmxPFRTgeJ1A4SjpMPBhua8rP/cJEqDcVCyk
      X40DrzeBuHNcndvez5heQmwxKfxDEfOV0g8PK9Rr2yjuRnlOIjj1lmRQQ8xfORbI0j5PBjAmbKs0uI9JbSv+7utukHfu20cXj3LFsPiNmeABPFGqg3EJD9EUCSuvl7KFSJN9DPqhrsFlobcdf3GPua5+foJbKS6jNWODiTYs1vq4xcDBgm0Onh0EdU+g+O+
      oOXBc+NP9PC8bDy8/vPy3uE7EOhKek03CmwVwKbYVIBX2xJwtHNUeMnDAJw+HdUtxYAK+tM1ft+Da5sAf1S+4mfs2/DQdPH4AhQu0Hjc3U+obgcfhTt3VQlHX4dbt8+unqJR1TeD3e4+O+zXIJS5Cpk7JigsYazoYCWubTsC8bYE52A/85wIqp3WBVcV8Mq
      iG2SU70e8RgZurHbhdRuFh15IpzwuqUkUlSFdjME1nA8Y+u/gpL3RpaJNmmPXVCdG4WIY+ysocqBLLRcvF8uMpFZbUPA8s6Tb2czTF4cB/1jWbeuBi8D+kokof8OD2XBs8GU8cTSVPIyg35DbgOqcWPQmdqur904sHWUGj98KDSA22qwiQTKBzNpvOA02DW
      OrI+UJjWJ0mx5hKvRN0BGW7Lsr2EvyozwkzLhhqZSiUzz/UPD+dLTHpJHCdTwE9AP1/eBQaEowL/9r9CR9dPEp0wqG3VmebmmB8SSw85LiVfeBG8w5Ral3QbyVbUGHR/QGINv0YWBJZv8084ReqPxCoWW9oAIBGnhf8MDY34YGtHzZKRvGXR1vwhQV3dima
      zzc/LBzkQHeOCo0Gbk3gx6bdE23MBcprPj/16MlM2mrvD7MVPYDdD9old4NaiGl6RlR4BoEQ9IQkEYGva1D2OJtFt5Bt8vgJakFPmfHU1/regKueHD5+/pKG5dzg2IaRugbpQjn6teIJhgvWpAI4Va2rSxwOQ8N2tGpi6w9MC+jl50O8Au+Aea8FoQvnHo0
      7pG0XagtQLtQFIJf44+9Ea/EVwup3/qFV/0XCwoAz9NyowZSRlZI4eOtVwIVKyvy5cxKPoxKJnlyEswgO6Mmfjis7Bn0HBHOtGEYQ4x1RKB5LSa3u96ZY3ZuExqgKuTELy/r+K0uP+qjoZFiMH107SsSjju9jCIh4JJ2nRNHXt94PEJ6iE1hgadceIOyo69
      EQQGzMj/tybrBtJIGoxl7XOc6E73pCR8+eoFE9FcZuZhDka4RE6vasZTsKPKj9+BZh0/w+LLXiop6basbva4cwQp9bcCj14iS/HQC6h8egkdv2zHD9NAxuyxnLcWCUWMaT+Qn6ds+19ugY2S549UhujPuNb3KfSr6AzzWs8cHg/0jgHHWpifHq64eXjwtm4
      KcWDO3X12HsGJWGiVtaFxk6PjzHTUBKoznzAv0CrOIk03FdFQGhAH09SIUWDGsE0P4zxsoYuuOv+emyunS/UZM9f4IBLAk3xscGtd+7/ezq53MNxD6Q46Iz+Lbv3tw2W6bRZ5WolwxSTI3Yjaqo+RGtPxe3KAyNJnfdLjdDI35CewiCXa/TCtfil1XUVwKy
      DDeZ0jF/amt+gmWUY0e7v3IWy8f5H9DjRNguGxI99MtLtNzu6wjFQN1X3cexTRID+zDlgJAD4/vt6OS8MM5cBtryeH+Q8652z3HfTlqiCz4jBMYNg4SM4EJFlwmZpSmVgromedhBfXTlP0L76gtZ7G0owldJcOGBybHygPELuHy9Mpcr6P3gXDK39iDt3im
      QbNw4t9Z0bBgFHMFAWi5CvYCj7xgElWXxhYuNg1JT3/SBxoNtPmSYSYHp/mz+9PInTg1hhmTEokczuSWNhrwjqyk/6LzPJAUBcx8c3wkDXzU9E7LtWRzHQlIjLWsicUdQLdBlEv4i52atwQjC4SXWqS3PkzMeN+rQ5MzIONRNOZkZgc+KGYosG6zo5F8qbj
      tIgsH6xkUWQsaxhh3WY2y/fvjO7rHnDcudW4OOL3Nhn2e4SRUXRQgy5Sx6A9Ix2hd0gRs6kmtMxtPnzsEGoc3tHMiZCA/lo4tHKeYc1HsSN8pv8MvFbmSo+KTot/DhlXtAcvVQmD4QxmvCd4xr172+oQsjuA9rWBdmeZES1kXH95rIQanNQsI5wnVNELDb3
      jRQPblfBNNskpDGZ1ePrtiH3U6VFNUjll9umYdH76RwA3ALLFqFHhL/VXWbNsiT98NWppvTsLjlMEVLkTcqfLf9GF2ve538NzVGXOnUtrv6elHYFaB6IeGCxwcJdRVIgD7u//OmdXCastr29VTZo7tvM1ApiPi0W+Be1Tbj1trz42AgLZpkJhLhKj22JcTA
      ymZZkjy/XpKD2LdgXzadqN/IfGgduMzrBTPYoT6AhDIgGVC6EPpx/9c3BxXPjrML/dUO/CxOc75qu0aZPUK1ivxgC6jtgbOVQ6fy9gRpjlWSKQFS6ZCPQEzF3wbSroSL/4kdArfHp21iPDITRkiTUnGwshzDuUa9HuXj+PdYHLppjeSOsvVPbaxHQf3dELf
      00n06tioavssTdQzEZgXYOh1AyqtSSJkuA/LZ74qwNsLxvLHDNo5qkOUBp2PmR09wTy0NEPqtNh1IF9L9+tzKf0udyUrm21XAzuwWOrpKx4O+nYr9yXY8Z3qO44zoBPEg8f8IMUYqcW2ZLTuTDUnyjRQANw0/A94e4k/sKFlyDdlkZccKz8lGBsoXDeWZCd
      L60aX/lnLF2EiWEB/LwWHsx8fboeilPhjGEAAsoZW4rzP/ixtE7FoIi7lF8crGrgHScXHw7Ng3cBuBP7iDyIzeS6wGkPfFJQ7IpySBOw/ivD8e/VGschiNNrNwUAM3YLxhmYa46V49hAeE/clS57ZfF4b1mbMpbaOExz7ARDMjHsKjDLxfJw3nSf7CHcmtd
      Q/Ni0PByi1SjW4QZeOvhLOyz/Mfc3OVwO5Mz8w8yK0vE7XgG1IpfEx0XzG76fLBPHX1fUUKRMh6bMLxJBRI0xEOK+9OCB1fFTLsv3MHYwHbry3yckiRVi6gGbOliPQa/87U1o8ngJHvjJmFKH0L4G8Jsu06Xeisp9s2p0ZobHexhrxAjNJ6xns2ulBfmT8M
      AbYNResb0t0Y0GizovbfuaODw3ai5kurDC/7QukiTdL+smg7wNfx8foX5wTQsaFvv+spZ1ICbSDDJKw1vywglEWDePwoP6o6E7ZnwFXrtYUXRrw0npnqwCAJ6OAWCPO137nDRTSMgQYhlrNxPxBs5JgHkPVBrvUOiJ8WWXa07nM6bVIeqihHB/+wWt952kd
      xhCt3MBEpTnr79ufhdYhZ9C3FJpWnj+jAIqJZEAk9J0mG/c4dgzjwt+gYe7uZbYgbTC9+hLmPGYPCIf6Px/v/LuNC767g2NHMQT2onvjnvLFZmcsMfHoE9PA6ZokbI8Ksf29ouTJYaoH4x7xJfDHW2GkzE0EofPmndhBmMcUDE6XWDU5LgIiaTMDNqxraLp
      /r0+s/0nLZXcNxQlOgXiNvFvL+LmyAJQR6AuLigYsNr8T3WdLjfmmI5JSDUK4AiHEQHut1JjcohAUc+VU7QgKhkmwgekbreNeOBrOBootNm/fL8gssfFBmDFb11qD2a4KRJ5tOuvRizJQvoSRFTpW5qgpIA0HXad77UQs9gnUtHy9U5lFBRDmTo6jSZ9XsV
      +3w4CVZWu+uXICf2mHUpaTjNZBPrWpyqA/L0fGp+HUiOePWQth6cIPMrNZ2bKWtbD0LgxCPHhXJuFns6Md5nxXcvjV0A/2FptIRC9dtRYOBep4r/Kod700bsb6LPqhMv2vHPYtycgw0jQP57Oqn/BQvZ/0PmkXAchL+wH5QhhimbkLfW6CuXGdbFXuhq4eS
      Zxqj41nbA3ZSn1cnG4aHCntGZbBtMe/eAYx7CwLdd74HA0z/1TuQHTeoJiSR5/54+mPa+MPQMJ8LgY6ebt32ifPtJhH62nXFQDVzQ+gUQ9WxbZzxHzhIGIPjZWbx77nGdAySzjxQSlr/9I6wQIOP75D5yNz/6B2huxY0nUt8ro8jYA4XfRdhn2sRUk7i/6A
      nl35JVSHCa/JXAYCBTIybWtf1RJgETkuVwaUF98yhVeMGDKOcz8T3/d07tJpnzBLvTH5hKF3lr94hQmp26CjRZvLH9R+jv7n0XLfzQuUFfZJBdUj3UqGkoBEGzgIA1Wfr95juGk0f7guoPDeHDE+LtzrI7cpb9202de129o7dxzszjua1Pcj87ncd6ad3jG
      4e6Puv//j6j5cEpKQzcEv+zk2ipLalg6ire/MuAHQLriKhA/NudJoaPxPg641kafGwYsxDNrPzPbDKRQmzGaAerR7VDoUsgKUb0a5PyAqynPUwuWj+dofLRxePkjsePbrv9U1WJaUT9vebyqqIcvynAMDkwjSdSBgNHThy5NnUBkvsjYDJeLrtQRz0OsoyD
      doRZcAuqawB192fME48Z53r5IP4mSeIpsruzTaj6YclwcNHzDHW1rdtfe6hXmqubu3SvdNT/TAMQ3oBi8ftTFiGM/2cyFWD9oRNO14F4v5eFX5YY7C9joABYQEa6HYDR0gFdSLh5w0xivNrTtdL/VSCPyyI2edygz3u3I6GWH02Q0IQVzbbuwCQRt8XqFzu
      M5ZtezQhXTn/4but19xKNG7pFNgTNUrTc4R3gtxeDKpEn/doqA+CjfSMevaCu7aj3/04/5XgHFDrlF2Xep0X8PO6MbYbeKXifhcA/LVKOCNjviWBz74TrrdjRntk85cb3d8DHbq9bx33iEB3xTCJUXNQr+O5EppfFcyBziA/CDN5QjLEkHt8vv8FNbOnuId
      9yz54e3EoYb+y29GCYaE/BYCO0P5RkyXyp8xswaz2NPSCpM+CeG1XSdeGgEftr6ZD6BrS9OwxEuoSkgjbEmvXUdb9jDNpSmgb3CzH/4D64/qJGku6mlKI98XE8KIVxMLI9shPAWD6yOeFyrK7ho88IfONWxCeuE532fS2YcTc+LaiWoCOwHiJXFJ0dpoB0l
      5aSu3dYVwoAcoeyFqZUEWWj+v/7iAxipreowWhaI7g953seQYw91MAkEwhyHkOzVEDUA/MnhDtI1JA07EmNK9hnzkQAicyyQGexIvgtkkVrEXHOFjJ+Ely1cQKNKgTlip5nv1iH89/i8u80xovI4kNeLDd0dw7xjJSfhcAqosB9eIZ1uFPN8/tomjvk9WYV
      Y7zXginawT0DbuapeOnKOS+oCyliJ8yGIf81ynPQwf3OijZkDuXHFEzPr3+NOEp+iWI+dRiNu4XQjgB/VygFB+zAHC19ZrJ7KtlPOq67VPpuRCQgtjs2ivTanPwxHCMhLgI3yU8Jhl0ezM/jKMIrHxOBilwNxFimdQCf+7j6T/UYaRp5EQTtVdsCH+SFgGh
      vfCIWJefAsBa2j47dfidKaRrbwMpI1fhyM1Tmm6uY1K9ePSUe1vAc1h2MaSsOTWJEV+sGqwwS+kY9cEYihG21Zk32j6eAFRwoTWHi7jZtKRsGjOlU/wi2J3qTO69iFiQ6oXnnatb4TVt9qH4Dgy6v1EAPSJ1ffaRxnDPmCp4jWL21Ym67uOX4yNpTSuz+UC
      7WiGQCf63z65+auDSWZTdrBUYkaG00iQePzWKlaBtBnTqdYhdIIcljkCO992FOg40aDjbg7iYobt0dewXM8A7+grOkU+kMUEvcou/BL6ZBQobxhHPUio1wMf7/8vsadwmaiMEWR4yOrokWggoYa1k5kDfPid6Cp4UBoTXTBCsr7Os2wIX64e2qb02WpDRwD
      h8YBvGNt0iAuWMWAEx31+AD3oFJxAN7kYtqfe70Y/7P7D6WF4C8gtBOj8xCKIHO9jMaC9LGJ5WQif1Bwz8dk9uEh8ZzwRGU/KCvMkM9QbGpOqw78zeUXs9a2g3mcAXTeWvwHdYUflw/Fx2782Tzk8v/7Yuxfba8bkK9I1OM7fNSEtS8MlsikuWIptxHQ/yl
      B6JXlfcBLNogbwxd3T5HuOgC2hABwKnrNEz8GUSHzb+TnyWkhe2wamLSTt57o/zPx8DOHRbBoNb6SGRC/qltSQsH86uTK23ZZYijwV6puUlSd6GQepr3MwXEVLkbCEzdfo44NqBeRPf6z8TX55Xxem9KYNBYkPS9en1T/khcnq/hGGipDVTsc1u1pejs4gR
      I8IUPP00M3mP3DYiqhWg0lL96tH034NDgYJRBOW/Jj64W4+8IwpCAEjNx73fe3ahZeAF12tPw9dUyWxxKI9VSAPwzbVojw8Mu92UOBC6LEB0sLX2yMPVgkzbe3AItBmV/B+JL9gqy0wijRRkX3kMH+9/n2ssNO4LR8yW/dFiRD4swc8ub2sSIv1EO4Z8N5Z
      bLhUctUTWQ+0XQZyfEeQjiWnH5uls//yvic+foUnWrNAW8gji894fRL9xvV0r3hhlRQmV8pZfqy0toJmDpgvasGOpHJuz6OeAXvi/pUz0EphxsTF+EesQQ5DfQ5P/lPieQ5M5oY4IZ06NEeTz/f/7GpP1SMgEOEIWa2jq56tKwY4jWqQtYPpWgW+nmU3LYS
      A5chgRFyQAE+7VuhQDWi28aPNraPIfCh8/Q5Mktwn7XpbxdMSP9785ZCiROBZQ3YVd2raao9d3WxKiAXdsGOnPO7WMZJXUbpfXhvRvzkur6I1k+QxIGqbehChE+q+Fr5+hSW78ScwgTe/j/F8oAPmBvA4Z8Bqckhju8DUpNhJIL/b1zFnNMYe4ILFRUuaMa
      x8sbsvW+1hIva0GyonwDpGDyss/FD7/GJpkZpMEAecmNrN//Py9XkV/FUqWbYsSFKrpdN7Ie6VDl7WbvcxDrAJjYL3u2TDKhXYeNR3Dwng85IPzXDlZArfd/2Ph+9fQ5H0x2jA2Ite0IdaP85/rOepkbDonlgz7MUgiwTxITrYCJl0LxDXP9o82tjnHIRZJ
      7TE7IpDJHvjuWXhBz9dLLZd59X9tfGh/H5oMZBwNoiJd8M/X/9vruQhVuS5ha6tnYmJ3MjSsjab9mIPAai25IFEOqszCAE9kli3WBNbBOk6KFAlkR6eXy6VN2f6l8eX496FJCVb4Rz2zV/h/IQFyNumbd9FIM/OxGLsW+9JwIvEd19uLFwwBuaGCoyNnNip
      4pTkf8K6E72t7SJCuPFeQqPYI7dxCFlHfjU/nvw9NVgQR+YV7S2j1n148zEZ/FYlXDR085LVMwIbH/Tp3JHywb1mAnC1RXTwTyqvN2iHhIeWeufvwRs8ecUAQfTNmoVL4JR27mI1vFcS/D02Oo9AGcq9E9fLx/g8ry0587FnNWfyZjjb9ahuXcgMx0TEVaz
      T4+mknWMkZ/GaDXDrcZa7evPcg3H65UDma5dIx7d+Nj7MK9h+GJjeOOFGhYXBl9cfx74bo9og1IDlvc6ZN2nmXCfVLBC3R23WKpHUWOebcB0JkeDdIh1aZvtbYJqZfD6ivnSFD8qNsARhnTA4g/zA0ibF/t3lT9wKlfXz+cdmz3mvQ8OwB2frMYq5zOgFmu
      icv0PyCwA4d47yzQCH+XSW5g9x6I9c9xEqkc8dgM5d/VyBlejyNUElH8g9Dk4Ku+zCoQOg07cf7vwsD1d4e+zW4AjVntZV4/2OO7VS/R/Tc+1UZ9COvUtQbQ0PGP3RkeMcc9Ib4TGCMxoE4p/Xr6WRnc1TiPw9NNn0sDAJfnZqTIB+WXIJr2awE3viebHTO
      hGyvc6CLOm0iMtfjNbdiAWVcXQhc8gzLm9zke3hh30xvuYtR039sUHdLN43s6T8PTe6liQBeYSzVH1/+bGIo1MAxhz/xv+uDBu3zDs8zkx2E3YxeN6Lb9jrwEIXL3oPDw166dXOsz5pxQrk4KsGN6GiAR3iMH7BZ/g9Dk201AoNNfu17Ux9nwDlu6JFSWJY
      dQ31b+auLF59oB0/OdEOblzEjVzPoByqa+zo7vSZfGIdHFNvbgrQmnEh8id3Q4MHoNYJMkYn/PDTJg+/yXGIFpvvH+7+GEZdEP11mTXtWNiqCU+Q8h5vZ22WZjTAsoCGr2A1BtMvYvrzn9oXkofaMS7gIn22knG2dwcbfjcNyi529T/dvQ5OtpJr8vDKJCg
      gf93/W4SODw3AnJLRGkMu/QCHSezCeF1aEEaZZV6nYwm9lrSypiieqi0gnur/3YOdy/THO4troFYMjms2/D01SU5Ya3RATWbqP33+SWkId0GjEfJZ4srdI80ANNttZemlXH2yEd1ETwQwRHOF9gnlxDxdz4K3ssyFgq7Mffnkjoi1PGN0L1ZGq9rehSaJYl
      feQbdbLERR/vP4H8ajMec/xgdH1n3zv/Cowb0CigRtd25OJXihgUA8RynHtq8KDdratZWa3AenPdu4nmk9BPUKA+x6Mg92CcOTvQ5NKIwq8qBAM1p6ej6f/cZXmNbENUtHD7he6gOuBd1Ym7YUpDNSpg9luQHBv743nsl3dzHszrHa2Ogv6DhjH+rWG3sNZ
      kejNZiphV+/SX4cmJwpKazBupYmir0S4eOiP+38LlFwvSJPczMlEDOF1A85xD1qWXNqMRyvllbVYC3/sWqVUPnonETf5UYeBcRGbhLmOvrnJjO0CI0viUi7yL0OTuwdW1txnx1HXyKyo5enj8x9cC+IQ7GC4tz9k3NsXMXmzlOV1Tds2xrU4WlhdOMP4XnC
      FqndR6xZFvucNJgjvjIetMRZmchNSmgPBS2n78efQJBBHpBbOE9Pw1N2cnY/bxwHQlRgejK/waDMngcCuwviUt5MGx3u8HBQBsZoeHjs71n5GoPZL7jM30GuaFJbMdTwIcPa1ZMqO5eiIK0OofxmapAiZDI1S4Q+R9016ucaP5783GyluANKACKnmBPbUIG
      xFAw5HHRt5zWy9hzoSzJH/SY3e7ZJvH7FC7DxBXI6Mmlw2j2Tw6P1GpuBxH+DPocmFUYlb4rUxPGuo7t1Owz7e/5dTJXzrgs7Qle9zAVR1xmxlwfWSYppBfUG46+btFp7NtP4x4/0bMMBBex/JS/mTypgbFNO6vHRq0Qfyx9BkFkxJPXKeCREPolBSZ/P7x
      /NfTGK4UrOj6Q3FnusQbD+r4pCUnikhsNZbq4lGwuYIb9bnC3dpJgJrXpRDVih0QHD8VzLT97IO83to0niBSJdHUm6yBM2JjGURBENi+ngF1ImwgarpNkfBs6n3HZGsjVGF1mQyN1zM2KtknFORG8k9XLtGAqdmKrww6ZEdA9ujANwOT1ADkPrHNShyhFrf
      mRN4UZEQWhY+CKV+R6BBZR5OLfXj+f9qWfTcN5fSvm47+m4/07kiULeveNJ9Foe3lRoWEB0v4E7k9hgA3lc63YomtJfXvobZOngiDOqtpdGDEDuGxFLnFO2OlLkXDIGuY+SbhdGZ9bHx3BX9/P0XRWxtR8KnYT2PCxdoCPIWwqhCR1/mdYWz11luWuyrrUZ
      ZcyD0Vem1IhV6TRsmyzrL3UduuAHPde0u9URYiRqDyTVYbhQcmsGh9gKbO959ttSrJVhPP71+Mib53dgc7rgHRnJqaqIRGKIdhTiImwt5QcrG5BcqsVcQCRGhsxOJgKnSEEmQ0hGY9wSTOS+5p3WCYin1gVqzbBg66wxz4bwOuSA4sgg1wMBK9Zo+fv9ptI
      GcgZDQ85hJPJBrne0OwrYNiNmk416iU9d4mluL6Aey1nMOgK1HRBe44RbA4yiGACuJlyJFo7mzSG7WhkFfm+FcRrALWvm92Rkl0swbi5LE0j/e/zRgtQSsrHed1x5fe9k3oRwcErkQIvTdMKtZ7QbxrkCTZn2YpbbJ/+fFUEVqr23I2nY671HIHh2IvwTv0
      t5yTr6vW3fM9J164Cr2sYo1HAiLYz+iah+f/+UYlKyUZp03tbWXP0tf0RpQndEnLCBzWihvVA18kerDk1wtJerolJL7aISS7HmDwfjF88pcCWNLLxcJy6dZR9S72pD+ho0S0XomYyIMKscoLN/Rf9z/t3ntRZ9xKJp5B5hb9byyHHFg5WGgN1jEvN3gfhD/
      wf6kvlKupdAv5sl7aJJohfHMIqZn+MMaET13CJiO992g+9WXiIqEP/rT6f/MtpF1Ek4daHvcZxcP8/o/dHGqnoht7SzlonWiW/dZwvPab3T/BqEr9IAUIatoZtrnLjJd7N25P4cmlZx3QeFSiLS+RsPEvuu2vhFVZa2Cqwcl/Z1kz8tsAhuzafiBi9r+cf6
      XTXMm5zaZWJt3Fi0mzh4WWe2+hTMopa2ZRzmRrHtj14HM1qzHvw9N5t07o6Kt6Rx23vD6gG6BIpfOCAHtYrUduSkEvTyD177N3PGHZV/wMbYVHfyccOjo9+d996sxMfTdRiOR31lYg4FwFaRxFBpdl9xzjn8fmixbwiUqJhyhBrFAgx1EvGbzw9K5QYfZmW
      ZzlAy9yyyog94+v/4zWc8c1JUXCDvnOiNoRUys151bAVJPZIvKEV5H6ZpBjcupZt9+WSH9y9DkReXqGPEIbhe3DvT8MK9+xeAvq0EO3fKBCpZL5W33ggGxED5e/91XWaJxhiK1ARITpeI8GAjRhkaKss7rKmMHub06Gnjbd4R8pM2ed62XJf1laFJnsOXY+
      gHm3OZkvznntPzMlarLw3aeM8B2DURnmY1o5z4+P//yM+mJaJ9ZRGuQZ0PjKAPKuRDCg6rUlY3011PJAbeGrNScfOgNETJRwfw5NKko8b0/T0cUlVEzNIUNZutjY7O2UG9wA1SAWWGDllcooz4fx/9ArXTjWDSIYPBMR6bZnnCVCIvJhONh7+OaxbBsHlyk
      WzmCY/syNvPiVQ5/DE02Ziy6ivK8ywAnmxekEYUGnkPQ1vE0+Gk8RPduBLLvoSP4ePyX0LMNSHo1574PW6oKsl+pz8G36Bu0UXScwW2Jdk7LQ1/M8WCgh3jo0fzifg1NYggNcwAW1xRQRXi7hsfYhzviwPdjV8EXjCpuXAKY1j+Z/4/Xv3aDOk8I9bEzQGa
      +H4PC0lLPJsZl2/L18x0V78dtBZZbbdmcQweEh+o1Zhco/AxN1uTW2U5pA7+OWVjQeNCoE6Xm1T2nNAp5xEgYT5E85J4wfJqP538cEzP0pcwQCMxb//ZCCTp/ZDGRIlrZTyQrS3j3acySPe9zmOVKuP6A1GemiMgMBX7faVtSeieGGLyaB8ZHFZ4jr3aRl3
      3aPqU/V35wH69zz6A/nv9rs95B99dLw3LFtcTFzmtAlknwfD5eePBzuD/9XNXwYCxEG+jk9cySAamMsI77Na8H6Z1XAxeP2/zJXqMT6PjndwuARNMZtU0HiOEW+FhmXzg8JXweABM4X+yZiXASUPMxhoXj7oRX/sBsbd+DmJOKZj80nv28uzq98syBD5Nfo
      9SUdiD7jx37TeA7a546cM3Wf7IfDuIcjV/W+eFzatiOcXddJEaHo30c/6IVu3mrDdfX+yxiGCfV6LBOh87+PdRvufbW9NQwLAr1qMf/urvifpbGTYseg8T7ClmVUrSJpTTiNishj5R9QH51h2qwY3SdQ9T64PVQLsVZKP14/9eOj6C913q1PzcSMMZXWEbc
      o75vGwOMG723r4szeg6LgYqAMAh/sBauEMFjOKhSo+pHsaJnH5sw4PYTDAKmVJdV6xr48oS9uwSLnXetIi80s97Wj4/3v77uQ75RYFsFe0+zkwS6Y8hur12VA7YrlXvbe63nvN7VzgtOESGBM5WBPK7ex1btgux5eOksIUMK5plisi6g6ghsZtbX5cH4Jw6
      E0sFcINefzs/t4+tndSwQzry3uJp3LS8W9N8z26X5uvHtTrDt4lgom2MNg47T4m/1TRFE8JFzyhmiYbcj/CMwe2MNwcjA8CW1dURXQ0IBE6VagEHpzVo2uyzYj+f7eP0LKFolh7G12Od3gNHA4YpIYgZoVGIy+f48JPfGKmPAvOYIbmv3s5Rf99eQlfCr0P
      e/I3tEK0IQPJkh4sf8Uy+8Z/8Dw49g+DmUrS5eB12fj8OfmcZD7cwrPpnsM++DK5UF/TXG612kBnGdh4TEcKZqJwpyrzm1vEZEyKwpfjoM4+gTup+XOUdt3OyTeDKSpfktP3MGlnJhRyJ5dlWzgXBhO1IPDwKr5+P498SDnBcgzEGfXCYX+rmTCv8/jSPEB
      +xuCdvtMNplZY29tJNkfm+SceW2ra8hACHHslBeSCk+vm+168iRLq7EvAiR1LY9SHm7GTe0U7QtTQK9CuE/3v/0OHmjY7bOEZnfp3EThHzcIwjeNSL5MtCRC4dstW0jl/1VidHKDrvs/WX8zqTOVobOyGIXTZAUg6TNmAX3akHMYzcGvlofCuRdPgs0vWdi
      9grEFf3x9XMJMldScxVLZwPtNt4I5ucNJ3M4cR8bevFUVFuUUptbd8QAzSlJi5c5+DV4pY7cV2r92g0jlCFuTit6UJLE2pQT4gnBSxBn4rLB3lRFjCwHwgHB+cfrP7Ole+leUn+oRN2lPbQEUqV1XnrDrmOvkqezzAelJkQOvASJJ2k3NPhTFctKvRzflI/
      tJkil5lWpG0fguxxbEfuC4WNyCMPNpoGKPPqSi6Ee179+Hv6JNH3ahRie7WiisM47r/zybHBBWvC0JZJY1FoWO3SuUT+EE7H39x0OnvN5me9rMSvGs3U2wh1bq6nM1uiGDOFE9ZljNL/GnNrz0N0qZISVQiMhfd7/ZT7Hc2FtaKG5/+pHM2Ne5x7mlzh1Of
      O8tZUb4riI34LPVel5h4dCO2YLIlmQaT3WRKcLPcriHILBNJHtiiahjpLe13y+Q/2T0jO7xPeaZ13Yfvz+m1dnagZoU0lYVQ6TkSIxQTVGHn9yNAbXEnv84dzrQeSX6Wxqn3e4VPDO4ZbddDY8He8vTsGgII1c+6T186tSpXTH+w6YYXwMxmmozM0+iVQum
      ldvPj7/eIyVz6+8WbzmyHvnt7cAbSwHSrJ7Z2d9yXZ+KepdDxfR5nMhP3f46PdYm4mB5uiYHkeXRrClbCE3joZVnNZ8Q27hFmbvs4U6LkBtcSWuweiHlLF/3P/TUgYXdT8HLpaPOq/oYULrvNa6zMwPRSNHHINnJ3lYq0Tl/3WHU1e65JnHikQpjJgyMdfR
      tRmJVrWIYWdXrOBQjrOycY2956vPyJLPCwPNFnOUHz9/wraVQOVnIimq7arnqXNc1lTy4vR73gHqq2YzZ/eJbwLR/s8dXhB3Ol7rvCIAld17uRiqZCOzFRghz4Z04H2pLG7GeVdGS3YIj8KEWJQSNJaDfDz7jUIrBKDorsI4iGk9jy07tAizWAk1HGw9L3h
      s6vOOd5WW5fcdbrNd7CAKGeArU9vTvCx71Z4Ary/QlOJWAKH7uys8PA3YzAikrsBvIB6f4t7n6NSHZU5w+V5P//4WvNn5jk92C3FStiCjE3dIAUYz+92B3z1v/Y87/GB+a5JSzwN3Q9/P7bKUdcKm4xlroWpFmBN8+4lxz6mO1BQEgktWLM8L4M8qP97//n
      hr4dx9UZB4wVW56RMGnC9N2/zeA8TC4YE9nQuk1bBw/b7K5j3nipAIHs5eePpCFsuP9xfe2kt4q6fTQPBbkPLOSZm+1FlCXRZUqqbinpAHmY/n//rRS3EFyS4C4b2AUNbbdxv/vMPTQUdc9JpXws+LgdjiOfnjDs8yUx6zl+VBXOiTWVyc33k9x6jwR2r3v
      szpx/XVosJN7kAa4ox01IK2hHYDRH++/IMOes4rstnMQg7Euly3n6z8vMPVrIX32es2y9trmTZM/rjKptpS319y/W6dbHxVQc+vEDwRCqK5y3ymsiGCuDu6EsE4mV8x3Gfpc96N+cZDn4f/v+QgCz7qVkKJfuYstrmuGaDLmF//JmaZ5NVqcPEvV9nUjcp3
      YQD5TyC8mrBIDBIzydv7/r4BSWCYyPJ12PkVu/W4MerNpMn7twjIz/f/f+UrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOU
      rX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yFYD/B92aGZl3Kab3AAAyGGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU
      0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4KPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNS4zLWMwMTEgNjYuMTQ1NjYxLCAyMDEyLzAyLzA2LTE0OjU2OjI3ICAgICAgICAiPgogICA8cmRmO
      lJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFw
      LzEuMC8iPgogICAgICAgICA8eG1wOkNyZWF0b3JUb29sPkFkb2JlIEZpcmV3b3JrcyBDUzYgKFdpbmRvd3MpPC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6Q3JlYXRlRGF0ZT4yMDE3LTAxLTMxVDE5OjQ2OjM4WjwveG1wOkNyZWF0ZURhdGU
      +CiAgICAgICAgIDx4bXA6TW9kaWZ5RGF0ZT4yMDE3LTAxLTMxVDIzOjI3OjM5WjwveG1wOk1vZGlmeURhdGU+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxucz
      pkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iPgogICAgICAgICA8ZGM6Zm9ybWF0PmltYWdlL3BuZzwvZGM6Zm9ybWF0PgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      IAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAKPD94cGFja2V0IGVuZD0idyI/PhFEx7AAABHzSURBVHic7Z1PcBPlG8e/tKGbUvpLWjtN0GFWxiGpggmtmjjiRMFhEcf2lt7qrTc8cvOmN48ce7M3eisHNIpOgzoQmHYShnESBnRHhukWbLMU6G6g5HfIPK+7yW6yaTa2Ke/nAt3svn/3ffZ5n/d9
      n2fP119/XQaHw+F0AF3bXQAOh8NxChdYHA6nY+ACi8PhdAxcYHE4nI7Bs90F4LxceL1eRCIRvP766xAEAQCQz+eRy+Wgado2l46z0+Ea1g4mFothampqu4vhKrFYDJIkIRAIAABEUYQkSZiamoLX693m0u0MdmO/uwXXsHYwkiRtdxFcR1VVpFIpZDIZABW
      Na3p6GoFAAOFwGNlsdptLuP3sxn53i7YJrCNHjuD06dPYt29fu7Koy4sXL7CysoJsNovr16+3LR+v18u0BVVVUSwW25aXFYFAgGkmsiy7kqYoigAARVHYNM3v98Pn80HTNCiK4uh5q3urBZKmachms0gkEvD5fI7L6KTezbYNlduNfnSaFr0/Ttr1v0x/p9
      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'
    $imgBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage
    $imgBitmap.BeginInit()
    $imgBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($imageBse64)
    $imgBitmap.EndInit()
    $imgBitmap.Freeze()
    $uiHash.imgProdLogo.source = $imgBitmap
    

    
    #endregion   
    
    #region Jobs runspace
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable('uihash',$uiHash)
    $Runspace.SessionStateProxy.SetVariable('jobs',$jobs)
    $runspaceHash.PowerShell = [powershell]::Create().AddScript({
        While ($uiHash.jobFlag) 
        {
          If ($jobs.Handle.IsCompleted) 
          {
            $jobs.PowerShell.EndInvoke($jobs.handle)
            $jobs.PowerShell.Dispose()
            $jobs.clear()
          }
        }
    })
    $runspaceHash.PowerShell.Runspace = $Runspace
    $runspaceHash.Handle = $runspaceHash.PowerShell.BeginInvoke()
    #endregion
    
    #region Events
    $uiHash.Window.Add_Closed({
        $uiHash.jobFlag = $false
        Start-Sleep -Milliseconds 500
        $runspaceHash.PowerShell.EndInvoke($runspaceHash.Handle)
        $runspaceHash.PowerShell.Dispose()
        $runspaceHash.Clear()
    })
    $uiHash.buttonCancel.Add_Click({
        $uiHash.jobFlag = $false
        $runspaceHash.PowerShell.EndInvoke($runspaceHash.Handle)
        $runspaceHash.PowerShell.Dispose()
        $runspaceHash.Clear()
        $uiHash.Window.DialogResult = $false
    })
    $uiHash.butInput.Add_Click({
        $folder = Select-FolderDialog -Title 'Select the Input Folder' -Directory '' -Filter ''
        $uiHash.txtBoxInputFolder.Text = $folder
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Selected  '+   $uiHash.txtBoxInputFolder.Text + ' as the input folder... '
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
    })
    $uiHash.butOutput.Add_Click({
        $folder = Select-FolderDialog -Title 'Select the Output Folder' -Directory '' -Filter ''
        $uiHash.txtBoxOutputFolder.Text = $folder
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Selected  '+   $uiHash.txtBoxOutputFolder.Text + ' as the output folder... '
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
    })

    $uiHash.checkIncludeSubFolders.Add_Checked({
        $uiHash.checkSubFolders = 'True'
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Include Sub Folders Selected'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Yellow'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
    })
    $uiHash.checkIncludeSubFolders.Add_UnChecked({
        $uiHash.checkSubFolders = 'False'
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Include Sub Folders NOT Selected'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Red'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
    })

    $uiHash.butConvert.Add_Click({
        $uiHash.progress.Value = 0
        if($uiHash.checkIncludeSubFolders.IsChecked)
        {
          $uiHash.files = Get-ChildItem -Path $uiHash.txtBoxInputFolder.Text -Recurse | Where-Object -FilterScript {
            $_.Extension -eq '.wav'
          }
        }else
        {
          $uiHash.files = Get-ChildItem -Path $uiHash.txtBoxInputFolder.Text  | Where-Object -FilterScript {
            $_.Extension -eq '.wav'
          }
        }
        if($uiHash.files.Count -eq '0')
        {
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = 'ERROR: No .wav files found in '+ $uiHash.txtBoxInputFolder.Text + "`n ▸ Please Select another Input Folder"
              $Run = New-Object -TypeName System.Windows.Documents.Run
              $Run.Foreground = 'Red'
              $Run.Text = $message
              $uiHash.outputBox.Inlines.Add($Run)
              $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
          })
          $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
              $uiHash.scrollviewer.ScrollToEnd()
          })
        }
        else
        {
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = "--------------------------`nFound " + $uiHash.files.Count + " .wav files `nStarting Conversion `n--------------------------"
              $Run = New-Object -TypeName System.Windows.Documents.Run
              $Run.Foreground = 'White'
              $Run.Text = $message
              $uiHash.outputBox.Inlines.Add($Run)
              $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
          })
          $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
              $uiHash.scrollviewer.ScrollToEnd()
          })
   
          foreach($file in $uiHash.files)
          {
            $uiHash.outputFile = $file.Name.Replace($file.Extension,'.mp3')
            $uiHash.inputFile = $file.FullName         
            $uiHash.output = $uiHash.txtBoxOutputFolder.Text + '\' + $uiHash.outputFile
                  
                       
            try
            {
              $result = Convert-Audio -uiHash $uiHash -inputFilePath $uiHash.inputFile -outputFilePath $uiHash.output -rate $uiHash.bitRate.Text
            }
            catch
            {
              $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
                  $message = "Conversion Failed`n $_ `n "
                  $Run = New-Object -TypeName System.Windows.Documents.Run
                  $Run.Foreground = 'Red'
                  $Run.Text = $message
                  $uiHash.outputBox.Inlines.Add($Run)
                  $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak))
              })
            }
          }
        }
    })
    
    $uiHash.butSelectmp3.Add_Click({
        [Reflection.Assembly]::LoadFrom( (Resolve-Path 'C:\Users\penwa\Documents\GitHub\WavMp3Converter\taglib-sharp.dll'))
        $uiHash.textBoxArtistName.Text = ''
        $uiHash.textBoxTrackTitle.Text = ''
        $uiHash.textBoxAlbumTitle.Text = ''
        $uiHash.textBoxTrackNumber.Text = ''
        $uiHash.textBoxYear.Text = ''
        $uiHash.textBoxComments.Text = ''
        $uiHash.textBoxGenre.Text = ''
        $uiHash.textBoxBPM.Text = ''
        $uiHash.file = Select-FileDialog -Title 'Select a .mp3 file' -Directory 'C:\Users\penwa\Music\Ouput' -Filter 'MP3 (*.mp3)| *.mp3'
        
        $outfile1 = $uiHash.file.Split('\')
        $Outfilename1 = $outfile1[$outfile1.Count-1]
        $uiHash.textMP3.Text = $Outfilename1
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = $uiHash.file+ ' Selected'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })

        $uiHash.media = [TagLib.File]::Create((Resolve-Path $uiHash.file))
        $uiHash.textBoxArtistName.Text = $uiHash.media.Tag.Artists
        $uiHash.textBoxTrackTitle.Text = $uiHash.media.Tag.Title
        $uiHash.textBoxAlbumTitle.Text = $uiHash.media.Tag.Album
        $uiHash.textBoxTrackNumber.Text = $uiHash.media.Tag.Track
        $uiHash.textBoxYear.Text = $uiHash.media.Tag.Year
        $uiHash.textBoxComments.Text = $uiHash.media.Tag.Comment
        $uiHash.textBoxGenre.Text = $uiHash.media.Tag.Genres
        $uiHash.textBoxBPM.Text = $uiHash.media.Tag.BeatsPerMinute
        if($uiHash.media.Tag.Pictures)
        {
          $image1 = [convert]::ToBase64String($uiHash.media.Tag.Pictures.Data)
          $trackBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage 
          $trackBitmap.BeginInit() 
          $trackBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($image1) 
          $trackBitmap.EndInit() 
          $trackBitmap.Freeze() 
          $uiHash.imageTag.Source = $trackBitmap
        }
        else
        {
          $image1 = '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'
          $trackBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage 
          $trackBitmap.BeginInit() 
          $trackBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($image1) 
          $trackBitmap.EndInit() 
          $trackBitmap.Freeze() 
          $uiHash.imageTag.Source = $trackBitmap
        }
        $uiHash.buttonSelectTagPic.IsEnabled = 'True'
        $uiHash.buttonSaveTags.IsEnabled = 'True'
    })

    $uiHash.buttonSelectTagPic.Add_Click({
        $uiHash.imagePath = Select-FileDialog -Title 'Select an image' -Directory 'C:\' -Filter 'All Files (*.*)| *.*'
     
        $image1 = [convert]::ToBase64String((Get-Content $uiHash.imagePath -encoding byte))
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = $uiHash.imagePath + ' Selected'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
        $trackBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage 
        $trackBitmap.BeginInit() 
        $trackBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($image1) 
        $trackBitmap.EndInit() 
        $trackBitmap.Freeze() 

        $uiHash.imageTag.Source = $trackBitmap
    })

    $uiHash.buttonSaveTags.Add_Click({
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Saving Tags...'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            #$uiHash.outputBox.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) 
        })
       
        $uiHash.media = [TagLib.File]::Create((Resolve-Path $uiHash.file))
        $uiHash.media.Tag.Artists = $uiHash.textBoxArtistName.Text
        $uiHash.media.Tag.Title = $uiHash.textBoxTrackTitle.Text
        $uiHash.media.Tag.Album = $uiHash.textBoxAlbumTitle.Text
        $uiHash.media.Tag.Track = $uiHash.textBoxTrackNumber.Text
        $uiHash.media.Tag.Year = $uiHash.textBoxYear.Text
        $uiHash.media.Tag.Genres = $uiHash.textBoxGenre.Text
        $pic = [taglib.picture]::createfrompath($uiHash.imagePath) 
        $uiHash.media.Tag.Pictures = $pic
        $uiHash.media.Save()
        
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Done'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Green'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
    })

    #endregion
    
    $null = $uiHash.Window.ShowDialog()
    $Runspace.Close()
    $Runspace.Dispose()
})

$psCmd.Runspace = $newRunspace
$null = $psCmd.BeginInvoke()