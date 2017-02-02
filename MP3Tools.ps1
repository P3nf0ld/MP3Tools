
<#
requires -Version 2.0
    Author: Pen Warner
    Version: 1.0
    Version History: 1.0 Initial Release
    Purpose: Batch convert .wav files to .mp3, edit mp3 tags

#>

$Global:TagLibPath = "C:\Users\penwa\Documents\GitHub\WavMp3Converter\taglib-sharp.dll"
$Global:FFmpegPath = "C:\Users\penwa\Documents\GitHub\WavMp3Converter\ffmpeg.exe"
[system.reflection.assembly]::loadfile($Global:TagLibPath) | Out-Null
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
    [Reflection.Assembly]::LoadFrom( (Resolve-Path $Global:TagLibPath))
    
    function Select-FolderDialog
    {
      param([string]$Title,[string]$Directory,[string]$Filter = 'All Files (*.*)|*.*')
  
      Add-Type -AssemblyName System.Windows.Forms
      $FolderBrowser = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
      $Show = $FolderBrowser.ShowDialog()
      If ($Show -eq 'OK')
      {
         $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Folder ' + $FolderBrowser.SelectedPath + ' Selected.'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
        return $FolderBrowser.SelectedPath
      }
      Else
      {
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'User aborted dialog.'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Yellow'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
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
        [string]$ffmpegPath = $Global:FFmpegPath,      
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
                $message = 'Conversion Complete ' + $uiHash.progress.Value
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
Title="PensPlace - PowerShell MP3 Tools"
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

            <TabItem x:Name="tabConvert" Header="Convert .wav to .mp3" Margin="-3,-2,0,0" FontSize="14">
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
                    <TextBox x:Name="txtBoxInputFolder" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="0,5,0,0" Grid.Row="2" TextWrapping="Wrap" VerticalAlignment="Top" Width="479" FontSize="14"/>
                    <TextBox x:Name="txtBoxOutputFolder" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="0,7,0,0" Grid.Row="4" TextWrapping="Wrap" VerticalAlignment="Top" Width="479" FontSize="14"/>
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
            <TabItem x:Name="tabTagEditor" Header="MP3 Tag Editor" Margin="1,-2,-1,0" FontSize="14">
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
                        <RowDefinition Height="55*"/>
                        <RowDefinition Height="36"/>
                    </Grid.RowDefinitions>
                    <Button x:Name="butSelectmp3" Content="Load Mp3" HorizontalAlignment="Left" Margin="10,5,0,0" VerticalAlignment="Top" Width="119" Height="23"/>
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
                    <Rectangle Fill="#FF838383" HorizontalAlignment="Left" Height="171" Grid.Row="1" Grid.RowSpan="7" VerticalAlignment="Top" Width="98" Grid.Column="1" Margin="307,0,0,0"/>
                    <TextBlock x:Name="textBlock_Copy5" HorizontalAlignment="Left" Margin="47,4,0,0" Grid.Row="7" TextWrapping="Wrap" Text="Comments:" VerticalAlignment="Top" Width="81" Foreground="White" TextAlignment="Right" Height="19" RenderTransformOrigin="0.506,1.053"/>
                    <TextBox x:Name="textBoxComments" Grid.Column="1" HorizontalAlignment="Left" Height="56" Margin="5,4,0,0" Grid.Row="7" TextWrapping="Wrap" VerticalAlignment="Top" Width="400" Grid.RowSpan="2"/>
                    <TextBlock x:Name="textBlock_Copy6" HorizontalAlignment="Left" Margin="416,0,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Album Art" VerticalAlignment="Top" Width="64" Foreground="Gray" TextAlignment="Center" Height="19" Grid.Column="1" FontSize="14"/>
                    <Image x:Name="imageTag" Grid.Column="1" HorizontalAlignment="Left" Height="200" Margin="416,25,0,0" Grid.RowSpan="8" VerticalAlignment="Top" Width="200
  " Grid.Row="1"/>
                    <Button x:Name="buttonSelectTagPic" Content="Select Image" Grid.Column="1" HorizontalAlignment="Left" Height="19" Margin="527,0,0,0" VerticalAlignment="Top" Width="89" IsEnabled="False" Grid.Row="1" FontSize="10"/>
                    <Button x:Name="buttonSaveTags" Content="Save Tags" Grid.Column="1" HorizontalAlignment="Left" Margin="519,7,0,0" Grid.Row="8" VerticalAlignment="Top" Width="97" Height="26" IsEnabled="False"/>
                    <TextBlock x:Name="textMP3" Grid.Column="1" HorizontalAlignment="Left" Margin="10,12,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="606" Height="21"/>
                    <TextBox x:Name="textBoxBPM" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="314,2,0,0" Grid.Row="6" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" Background="#FF838383" Foreground="White" TextAlignment="Center"/>
                    <TextBlock x:Name="textBlock1" Grid.Column="1" HorizontalAlignment="Left" Margin="314,4,0,0" Grid.Row="5" TextWrapping="Wrap" Text="BPM" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold" Height="19"/>
                    <MediaElement x:Name="mediaPreview" Grid.Column="1" HorizontalAlignment="Left" Height="21" Grid.Row="8" VerticalAlignment="Top" Width="12" Margin="410,7,0,0" />
                    <Button x:Name="buttonPlay" Content="Play" Grid.Column="1" HorizontalAlignment="Left" Margin="5,11,0,0" Grid.Row="8" VerticalAlignment="Top" Width="75" Height="23"/>
                    <Button x:Name="buttonStop" Content="Stop" Grid.Column="1" HorizontalAlignment="Left" Margin="330,10,0,0" Grid.Row="8" VerticalAlignment="Top" Width="75" Height="23"/>
                    <Slider x:Name="sliderTrackTime" Grid.Column="1" HorizontalAlignment="Left" Margin="85,15,0,0" Grid.Row="8" VerticalAlignment="Top" RenderTransformOrigin="-0.528,-1.231" Width="240" Height="18"/>
                    <TextBlock x:Name="textBlock1_Copy" Grid.Column="1" HorizontalAlignment="Left" Margin="314,6,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Length" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <TextBlock x:Name="textLength" Grid.Column="1" HorizontalAlignment="Left" Margin="314,4,0,0" Grid.Row="2" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <TextBlock x:Name="textBlock1_Copy1" Grid.Column="1" HorizontalAlignment="Left" Margin="314,3,0,0" Grid.Row="3" TextWrapping="Wrap" Text="Bitrate" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <TextBlock x:Name="textMp3Bitrate" Grid.Column="1" HorizontalAlignment="Left" Margin="314,4,0,0" Grid.Row="4" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" Height="19" RenderTransformOrigin="0.49,-2.228"/>
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
    $uiHash.mediaPreview = $uiHash.Window.FindName('mediaPreview')
    $uiHash.buttonPlay = $uiHash.Window.FindName('buttonPlay')
    $uiHash.buttonStop = $uiHash.Window.FindName('buttonStop')
    $uiHash.sliderTrackTime = $uiHash.Window.FindName('sliderTrackTime')
    $uiHash.textLength = $uiHash.Window.FindName('textLength')
    $uiHash.textMp3Bitrate = $uiHash.Window.FindName('textMp3Bitrate')
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
      zM+aPCiF/immdLlVdd17Gemc1FWR7yY2zK8yxbpp9UnFkbSLtUvs/g/w62m/n/7e3t8I6IfXim98dMI31BmyC80uKc9kf8nlYdyze8l5Fe930+k2nSnrqyLecc+Oj+n2nm/+w7fZ5MSviw7FjtJsdUylD3M/1U3iOv9N+oHWf/rvB
      KHx/W+WwOIB5l5P0n7z2K1vg/hc2Yb+nn+W6A7bFh9uvsm/S9fDcYjRX5Ppr9P8eQ9FWWJcs7q+8Sj6Kt/I8v8W32tZ5Ofy/o40mOtdn3ZvNR1oP8envI8TzTZMzpNulkmW75O+iv2sr/pbJRvgOWbft7e/c17ST9wPsEadGmeOYU
      /2c8xiTyIs1eviU96vyvlFJKKaWeU5fa581072Uv+daU6yCXsGF9G82+a/r31F+19nm1P6w51JrJbM16jdL/fW0jv/NH3/xLayGsm/TzayjLOepH/OMxu7+U3uh6ltcsrVG/Ju5szWlW5r+K/bLc+yNf1jzynPbCM7nOnm0k9145Z
      w2XezkmsHezJrzbOsuZ64l1j/Vm1pr6ulKF9zrWvUwrbVfH9BmQV16jHqfEeiX3SZe97qUyn6Pul2xvo/7PWhu2Zj++azT2V7zcxy3oI6zzrQk/Vi/sl2Ne/7ch9yEQexl1zLXKtFWm2fMa2bf/E0Gc0f2R/0dlPkd9/j/F/xl/9v
      6QduKcvRmO+DP/yVgTfmq9+pyXewL4elSn9EG3T17P8sqw0T4T97M/c515j8p8rrbwf99HKZ9QpjwvMdYxfjKW0Z7Xhp9SL8IYN/iPABvTvhBzbfd/H3Nyj/KY//l/IvMo9fvd/7Myn6tj/s+5HTv0fpJ1LfXxKX2Dv4jLPLZV+DG
      7Zxi25P0652HGcOJi57Q1e534M/coj5WDf2vxIW0nbcqe2cj/ozKf8y7IflvWKX1H3866Yo/RWEXcTK/n1/3Z+8GacMKW6pVh1IO5pPs35/LRNxjP9+dGefUw2kDfi0wbEz/znpW597VLaGm9QD2+9L9SSimllFJKKaWUUkpdTTsR
      ERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERkTvkH4eXjmrZO46cAAADy21rQlT6zsr+AH+kvwAAAAAAAAAAAAAAAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeJztmYGN4jAQRbcESqAESqCELYESKIESKIESKIESKGFLoIPcjRRLn7mxY8cksKf3pCfdJYxjzyS2k/36AgAAAAAAAACA38xtGAbz/Nc1rncer2
      deGq75LXG3IO7szqt2bpe51n7sx8/wjMUdGnNyKPQh16+W9pdAx7vG9W4uz/vK695d3FS7EdH9pnH30amYHKeKPihr5bzE2n3xdarJ7z7IXandvWjP2EPO+WfuPB7byvGdi8nNHZ6tu7ap95M/V9vukry7/oPLfcS1sf7+nNbzUTn
      Og7R36shNqV+fwCfUv5TfbfD71vobFzlfs+bonPOO+us8MfV89MS+s/76TG4q6qZ7tFK7UTu6NtfU/yi//16p/laraK4z7hP9nhubq39au9pHXEbzoTWJ9tp2Tzykf6Vctjz/U+uurhc/nTmorb/fczzG8eqxXJ56YtM5rf+uss9z
      0Hxs5N9Rnv0zOLf+U+u/5eU06t8HevdotfXXue0yPM+HmodoruyJTee0/jqP9Iw9wuejtC6ncaV7o7X+NtbD8PwcHCdiNVfHIF+9443QveY18zvNk46hJ9ZIx7X+S+5Zfdu6v9P+67jSvFVb/xy5d017xtN+6Tj8Owf03AM1uazZm
      +qcrOPoiTXS8VumzfYRl4nyocfSfjUd0zlrTv0t/lrITQ7dm+Tum7njnfMbI6pVT2zuuOX7XtHmHKL+6rvWeaxVQt+9evZ/c2j9ZhDxG+tvbIa+994cuf6mtT49rwl9f127/q9os6YNHW9uv5lbJ3tijVz9lyKXD13vE37eXbv+fv
      85h5p+6R4998zpeqR7uJ5Y41Pqb/j3VX8/v7r+ts7kvu1oXpde//X5NPx7un9/1f1oT6wR1d/aaN0v1VLKh96n0f346vqn69le5ziO+TCsv/83/PxncdY//03P17c3Nsp36vPS3//8Of0eFD2Xr65/tOb4PK7x/q/98XNg4pHJSW+
      sjjUdO8/IZS36rl063xo71W4Omz8tdyfR/r990dhb+7UZa6X9qf37w5zY1De/1tr4o29lAAAAAAAAAAAAAADwH2B/A0BERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
      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
      IyM/3/3/lK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf
      +cpXvvKVr3zlK1/5yle+8pWvfOUrX/nKV77yla985Stf+cpXvvKVr3zlK1/5yle+8hWA/wfdmhmZdymm9wAAMhhpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6c
      mVTek5UY3prYzlkIj8+Cjx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4KICAgPH
      JkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6eG1wPSJodHRwOi8
      vbnMuYWRvYmUuY29tL3hhcC8xLjAvIj4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5BZG9iZSBGaXJld29ya3MgQ1M2IChXaW5kb3dzKTwveG1wOkNyZWF0b3JUb29sPgogICAgICAgICA8eG1wOkNyZWF0ZURhdGU+MjAxNy0w
      MS0zMVQxOTo0NjozOFo8L3htcDpDcmVhdGVEYXRlPgogICAgICAgICA8eG1wOk1vZGlmeURhdGU+MjAxNy0wMi0wMVQxNDowNDowNFo8L3htcDpNb2RpZnlEYXRlPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgICAgPHJkZ
      jpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIj4KICAgICAgICAgPGRjOmZvcm1hdD5pbWFnZS9wbmc8L2RjOmZvcm1hdD4KICAgIC
      AgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAog
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAo
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgCjw/eHBhY2tldCBlbmQ9InciPz5tGdrmAAARkUlEQVR4nO2dTWwTRxvH/06M7RBSb9IoG1oht6qwoxa8JFQ2KtVGRaoBtfEBCW7m5hsce+MGN67cfKtv5FIlqiihtI1pK2ykIrtE
      rVNBuypF2UATb/iI1xD8HvzOdHe9a68/8uFkflIEye7MPPv132eeeWbWcfHixTIYDAajA+jabAMYDAbDLkywGAxGx8AEi8FgdAxMsBgMRsfABIvBYHQMTLAYDEbHwASL0RFcuHBhs01gbAGYYDEYjI7B2cjOH3zwAY4fP47du3evl
      z01ef36NRYXF5HNZnHnzp1NsYHBYGwetj2svr4+jIyMbIpYlctllMuVhHyO43D48OENt4HBYGw+tgVr//79eO+992ruQ0Sl3TgcDvqvy+WCx+NZl3YYnQ3P8+B5ftu3uZOxJVhdXV0YGhqCy+Uy3b6ysoJvv/0WX331FSRJaquBBI
      fDAYfDgZWVFdy+fXtd2mB0NpFIBJFIZNu3uZOxJVg9PT3o6+sz3VYsFnHnzh3cvn0bc3NzuHbtGv7888+2Gkkol8tYWlrCb7/9ti71MxiCIOCLL77YbDO2DFvtfNgKunu9Xni9XtNtpVIJ//77L/39yZMnuHnzJo4fP459+/a1x8r
      /8+rVKywvL+P58+dtrZexvfB4PLSbZubxcxxH72fjdq/XC7fbbVovz/M0HGEsV6/NRuoi24rFImRZNi3faHtafD4fAECWZRSLxart5PzIsmzrfNSyU1uXWVuNYkuwBgcH8cYbb5hu6+3txejoKJaWlvDkyRMAwMLCAm7cuIGTJ09i
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
        $folder = Select-FolderDialog -Title 'Select the Input Folder' 
        $uiHash.txtBoxInputFolder.Text = $folder
        if($uiHash.txtBoxInputFolder.Text.Length -ne 1){
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
        }
    })
    $uiHash.butOutput.Add_Click({
        $folder = Select-FolderDialog -Title 'Select the Output Folder' 
        $uiHash.txtBoxOutputFolder.Text = $folder
        if($uiHash.txtBoxOutputFolder.Text.Length -ne 1){
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
        }
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
        
        
        
        $uiHash.imagePath = ''
        $uiHash.textBoxArtistName.Text = ''
        $uiHash.textBoxTrackTitle.Text = ''
        $uiHash.textBoxAlbumTitle.Text = ''
        $uiHash.textBoxTrackNumber.Text = ''
        $uiHash.textBoxYear.Text = ''
        $uiHash.textBoxComments.Text = ''
        $uiHash.textBoxGenre.Text = ''
        $uiHash.textBoxBPM.Text = ''
        $uiHash.file = Select-FileDialog -Title 'Select a .mp3 file' -Directory 'C:\' -Filter 'MP3 (*.mp3)| *.mp3'
        
        $outfile1 = $uiHash.file.Split('\')
        $Outfilename1 = $outfile1[$outfile1.Count-1]
        $uiHash.textMP3.Text = $Outfilename1

        $shell = New-Object -COMObject Shell.Application
        $folder = Split-Path $uiHash.file
        $file = Split-Path $uiHash.file -Leaf
        $shellfolder = $shell.Namespace($folder)
        $shellfile = $shellfolder.ParseName($file)
         
        $uiHash.media = [TagLib.File]::Create((Resolve-Path $uiHash.file))
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = $shellfolder.GetDetailsOf($shellfile, 0)+ ' - Selected'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
      
        $timespan = [TimeSpan]::Parse($uiHash.media.Properties.Duration)
        $uiHash.sliderTrackTime.Minimum = 0
        $uiHash.sliderTrackTime.Value = 0
        $uiHash.sliderTrackTime.Maximum = $timespan.TotalSeconds
                     
        $uiHash.textLength.Text =  $uiHash.media.Properties.Duration# $shellfolder.GetDetailsOf($shellfile, 27)
        $uiHash.textMp3Bitrate.Text =  $uiHash.media.Properties.AudioBitrate # $shellfolder.GetDetailsOf($shellfile, 28)
        $uiHash.textBoxArtistName.Text = $uiHash.media.Tag.Artists
        $uiHash.textBoxTrackTitle.Text = $uiHash.media.Tag.Title
        $uiHash.textBoxAlbumTitle.Text = $uiHash.media.Tag.Album
        $uiHash.textBoxTrackNumber.Text = $uiHash.media.Tag.Track
        $uiHash.textBoxYear.Text = $uiHash.media.Tag.Year
        $uiHash.textBoxComments.Text = $uiHash.media.Tag.Comment
        $uiHash.textBoxGenre.Text = $uiHash.media.Tag.Genres
        $uiHash.textBoxBPM.Text = $uiHash.media.Tag.BeatsPerMinute

        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = '▸ Length: ' +$uiHash.textLength.Text+"`n▸ Bitrate: " + $uiHash.textMp3Bitrate.Text+"`n▸ Size: " + $shellfolder.GetDetailsOf($shellfile, 1)
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Gray'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
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
        $uiHash.media.Tag.Comment = $uiHash.textBoxComments.Text
        if($uiHash.imagePath.Length -ne 0){
          $pic = [taglib.picture]::createfrompath($uiHash.imagePath) 
          $uiHash.media.Tag.Pictures = $pic
        }
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
    $uiHash.buttonPlay.Add_Click({
        $uiHash.mediaPreview.Source =$uiHash.file
          
        
        if($uiHash.file.length -ne 0){
            $ts = new-timespan -minutes $uiHash.sliderTrackTime.Value
          
            $uiHash.mediaPreview.Position = New-Object System.TimeSpan(0, 0, 0, $uiHash.sliderTrackTime.Value, 0)
          
            $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = 'Playback of ' + $uiHash.textMP3.Text + " - Started @ " + $ts  
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
    })
    $uiHash.buttonStop.Add_Click({
        $uiHash.mediaPreview = $uiHash.Window.FindName('mediaPreview')
        #this effectively stops playback by removing the file from the player not ideal
        
        
         # this should work but doesnt.. not figured out why yet! $uiHash.mediaPreview.Stop()
        if($uiHash.mediaPreview.Source.length -ne 0){
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = 'Playback of ' +$uiHash.textMP3.Text  + " - Stopped "   
              $Run = New-Object -TypeName System.Windows.Documents.Run
              $Run.Foreground = 'Yellow'
              $Run.Text = $message
              $uiHash.outputBox.Inlines.Add($Run)
              $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
          })
          $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
              $uiHash.scrollviewer.ScrollToEnd()
          })
        }
        $uiHash.mediaPreview.Source = ''
    })
    $uiHash.sliderTrackTime.Add_ValueChanged({
      $uiHash.mediaPreview.Position = New-Object System.TimeSpan(0, 0, 0, $uiHash.sliderTrackTime.Value, 0)
    })
    #endregion
    
    $null = $uiHash.Window.ShowDialog()
    $Runspace.Close()
    $Runspace.Dispose()
})

$psCmd.Runspace = $newRunspace
$null = $psCmd.BeginInvoke()