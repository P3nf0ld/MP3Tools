<#
    requires -Version 2.0
    Author: Pen Warner
    Version: 1.0
    Version History: 1.0 Initial Release
    Purpose: mp3 TAG Editor6

#>
$Global:tempImagesPath  = 'C:\mp3tools\Images'
$Global:TagLibPath = 'C:\mp3tools\taglib-sharp.dll'
$Global:nAudioPath = 'C:\mp3tools\NAudio.dll'
$Global:waveFormPath = 'C:\mp3tools\WaveFormRendererLib.dll'

$null = [system.reflection.assembly]::loadfile($Global:TagLibPath)
$null = [system.reflection.assembly]::loadfile($Global:nAudioPath)
$null = [system.reflection.assembly]::loadfile($Global:waveFormPath)

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
            <RowDefinition Height="418"/>
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
            <TabItem x:Name="tabTagEditor" Header="MP3 Tag Editor" Margin="-6,-2,5,0" FontSize="14">
                <Grid Background="White" Height="389" VerticalAlignment="Top" Margin="0,0,0,-1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="139*"/>
                        <ColumnDefinition Width="626*"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="34*"/>
                        <RowDefinition Height="26"/>
                        <RowDefinition Height="26*"/>
                        <RowDefinition Height="26*"/>
                        <RowDefinition Height="25*"/>
                        <RowDefinition Height="24*"/>
                        <RowDefinition Height="26*"/>
                        <RowDefinition Height="53*"/>
                        <RowDefinition Height="49"/>
                        <RowDefinition Height="100"/>
                    </Grid.RowDefinitions>
                    <Button x:Name="butSelectmp3" Content="Load Mp3" HorizontalAlignment="Left" Margin="10,5,0,0" VerticalAlignment="Top" Width="119" Height="23"/>
                    <Rectangle Fill="#FF838383" HorizontalAlignment="Left" Height="355" Grid.Row="1" Grid.RowSpan="9" VerticalAlignment="Top" Width="139"/>
                    <TextBlock x:Name="textBlock" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Artist Name:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
                    <TextBlock x:Name="textBlock_Copy" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="2" TextWrapping="Wrap" Text="Track Title:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
                    <TextBlock x:Name="textBlock_Copy1" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="3" TextWrapping="Wrap" Text="Album Title:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
                    <TextBox x:Name="textBoxArtistName" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="1" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
                    <TextBox x:Name="textBoxTrackTitle" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="2" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
                    <TextBox x:Name="textBoxAlbumTitle" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="3" TextWrapping="Wrap" VerticalAlignment="Top" Width="297"/>
                    <TextBlock x:Name="textBlock_Copy2" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="4" TextWrapping="Wrap" Text="Track Number:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
                    <TextBox x:Name="textBoxTrackNumber" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,3,0,0" Grid.Row="4" TextWrapping="Wrap" VerticalAlignment="Top" Width="297" Grid.RowSpan="2"/>
                    <TextBlock x:Name="textBlock_Copy3" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="5" TextWrapping="Wrap" Text="Year:" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"/>
                    <TextBox x:Name="textBoxYear" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,4,0,0" Grid.Row="5" TextWrapping="Wrap" VerticalAlignment="Top" Width="297" Grid.RowSpan="2"/>
                    <TextBlock x:Name="textBlock_Copy4" HorizontalAlignment="Left" Margin="10,4,0,0" Grid.Row="6" TextWrapping="Wrap" VerticalAlignment="Top" Width="119" Foreground="White" TextAlignment="Right" Height="19"><Run Text="Genre"/><Run Text=":"/></TextBlock>
                    <TextBox x:Name="textBoxGenre" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="5,6,0,0" Grid.Row="6" TextWrapping="Wrap" VerticalAlignment="Top" Width="297" Grid.RowSpan="2"/>
                    <Rectangle Fill="#FF838383" HorizontalAlignment="Left" Height="157" Grid.Row="1" Grid.RowSpan="7" VerticalAlignment="Top" Width="98" Grid.Column="1" Margin="307,0,0,0"/>
                    <TextBlock x:Name="textBlock_Copy5" HorizontalAlignment="Left" Margin="47,4,0,0" Grid.Row="7" TextWrapping="Wrap" Text="Comments:" VerticalAlignment="Top" Width="81" Foreground="White" TextAlignment="Right" Height="19" RenderTransformOrigin="0.506,1.053"/>
                    <TextBox x:Name="textBoxComments" Grid.Column="1" HorizontalAlignment="Left" Height="69" Margin="5,7,0,0" Grid.Row="7" TextWrapping="Wrap" VerticalAlignment="Top" Width="400" Grid.RowSpan="2"/>
                    <TextBlock x:Name="textBlock_Copy6" HorizontalAlignment="Left" Margin="416,0,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Album Art" VerticalAlignment="Top" Width="64" Foreground="Gray" TextAlignment="Center" Height="19" Grid.Column="1" FontSize="14"/>
                    <Image x:Name="imageTag" Grid.Column="1" HorizontalAlignment="Left" Height="200" Margin="416,0,0,0" Grid.RowSpan="7" VerticalAlignment="Top" Width="200
  " Grid.Row="2"/>
                    <Button x:Name="buttonSelectTagPic" Content="Select Image" Grid.Column="1" HorizontalAlignment="Left" Height="19" Margin="527,0,0,0" VerticalAlignment="Top" Width="89" IsEnabled="False" Grid.Row="1" FontSize="10"/>
                    <Button x:Name="buttonSaveTags" Content="Save Tags" HorizontalAlignment="Left" Margin="22,64,0,0" Grid.Row="9" VerticalAlignment="Top" Width="97" Height="26" IsEnabled="False"/>
                    <TextBlock x:Name="textMP3" Grid.Column="1" HorizontalAlignment="Left" Margin="5,5,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="606" Height="21"/>
                    <TextBox x:Name="textBoxBPM" Grid.Column="1" HorizontalAlignment="Left" Height="23" Margin="314,2,0,0" Grid.Row="6" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" Background="#FF838383" Foreground="White" TextAlignment="Center"/>
                    <TextBlock x:Name="textBlock1" Grid.Column="1" HorizontalAlignment="Left" Margin="314,4,0,0" Grid.Row="5" TextWrapping="Wrap" Text="BPM" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold" Height="19"/>
                    <Button x:Name="buttonPlay" Content="Play" HorizontalAlignment="Left" Margin="7,5,0,0" Grid.Row="9" VerticalAlignment="Top" Width="25" Height="25" Grid.Column="1" FontSize="10" Background="#FF17A600" Foreground="White"/>


                    <Button x:Name="buttonStop" Content="Stop" HorizontalAlignment="Left" Margin="7,36,0,0" Grid.Row="9" VerticalAlignment="Top" Width="25" Height="23" Grid.Column="1" FontSize="10" Background="#FFC90900" Foreground="White"/>
                    <Slider x:Name="sliderTrackTime" HorizontalAlignment="Left" Margin="71,25,0,0" Grid.Row="8" VerticalAlignment="Top" RenderTransformOrigin="-0.528,-1.231" Width="545" Height="25" Grid.Column="1" Grid.RowSpan="2"/>

                    <TextBlock x:Name="textBlock1_Copy" Grid.Column="1" HorizontalAlignment="Left" Margin="314,6,0,0" Grid.Row="1" TextWrapping="Wrap" Text="Length" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <TextBlock x:Name="textLength" Grid.Column="1" HorizontalAlignment="Left" Margin="314,4,0,0" Grid.Row="2" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <TextBlock x:Name="textBlock1_Copy1" Grid.Column="1" HorizontalAlignment="Left" Margin="314,3,0,0" Grid.Row="3" TextWrapping="Wrap" Text="Bitrate" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" FontWeight="Bold" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <TextBlock x:Name="textMp3Bitrate" Grid.Column="1" HorizontalAlignment="Left" Margin="314,4,0,0" Grid.Row="4" TextWrapping="Wrap" VerticalAlignment="Top" Width="87" TextAlignment="Center" Foreground="White" Height="19" RenderTransformOrigin="0.49,-2.228"/>
                    <Image x:Name="imageWaveform" HorizontalAlignment="Left" Height="100" Grid.Row="9" VerticalAlignment="Top" Width="545" IsEnabled="False" Grid.Column="1" Margin="71,5,0,-5"/>
                    <Slider x:Name="sliderVolume" Grid.Column="1" HorizontalAlignment="Left" Margin="37,25,0,0" Grid.Row="8" VerticalAlignment="Top" Height="114" Orientation="Vertical" Maximum="1" TickFrequency="0.1" Width="31" TickPlacement="Both" Foreground="#FFFF7D7D" Grid.RowSpan="2" BorderThickness="1" BorderBrush="{x:Null}" SmallChange="0.01" Value="0.5"/>


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
    $uiHash:imgTempPath = $Global:tempImagesPath 
    
    # Tag Editor Controls
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
    $uiHash.imageWaveForm = $uiHash.Window.FindName('imageWaveform')
    $uiHash.buttonPlayImage = $uiHash.Window.FindName('buttonPlayImage')
    $uiHash.sliderVolume = $uiHash.Window.FindName('sliderVolume')
   
    #endregion
   
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
      J3Ij8+y9ueRwAACDZJREFUeJztXL1y20YQ/jbyZJIiI2nGk8mkEZMHsJgnEPwEpvMCgpIHsNImhaEuXegnMPwEpiddmkBlqlBPELjJTCpTXVJIm+IW4vJ4Bxx+KNHyfTMc
      grjbxS542N3b2wMx888AvgXwMYCPEPGh4Uq+h/rv/wHw0wMAj66vr78GQAMxjviAwcxf7OzsfE7M/AjAIYBPAezcsVwRt4+hLdbfAP4YiFdERERERMT7itqAnZlTACNP8x
      zAnIhKD20CIAmQIdc8LLoFEU2bGDBzJoclEeU1/SYAJljXaQ5gRkSFo//Yw64EUATqn/v6NcH6DzrxYeY9GL0TrOtewPyPM6v/aQDr2vtdJ1DBzchFEJs2C6Bl+QPq6BoV
      VH0LT/uYmcsGOdZoB9Q/sdtDwcwLxSfrQJ9ZPHxIFE0S0N95zyoMMRM4BlC4bu5AyPrwZuYxzFN5oE6fq09fbEx/NtZqV51KW9DuMfMcwHOLh9b9sr+UbgQPLFIA8BWAMy
      XYIepN52Pyo2i49C6APFROBzIsb+wrAPtElKgPATiBcYdeOPQ/Qbj+XZFavw9aWL8CRi7AyHmCdd33ADwG8AbAwsPnrOa/C5VlFaxcgaddm8zSauvkCtjvQic1NF7T7JMv
      UJY2+i+stl6ukJlHin6ujvMA2syiHbW8ttYrays70NMVirV5Kz8Parp2xQt1POV+7sb3RHaG6H8hP3drunZBqo4zLO/zcd19kEH0XPPpOnHogyFirHIAHj7MYMw0YAZu1o
      HHjbvqYjkCMPiAFaTyfSkzNj079lpvq+0FEdW6+E1hiIF1JN+bCgRTxftZh8GRq+MZB8wyW8KXjugM0bHyALl8z1SXOh30wMp9nTaNB32ILf878/UDkHoGRGMehIgWbGZH
      r+XUFO3+zAwmf3MI465+kcGVdcrBKAifygW+qevbEqk6zgGAiEpmPod5kA+ZeeyxRjf3ZiBrldTEWd3yc67gVYLKCTPPrOB6bNGG5LEKxzWdQS+v5pQyi8bLT9r3HPIym9
      xW4qIJ0D+3eCUWbdfJy56Wz2pLVZszcazaOw8qDs9jefUKdoXqBv8FYz2eqOaTW/DlKZYu8Tm3mOkQ0YKIJjBTa527OgDwu+9P0nDof6yaTwLSJqHQrsyWa4blPUgb+Gwq
      9gu6Rt8Y6wImR5U39PPlsZLQC4nJzdSppmu6eBRyzcdYzuYAE7s1Di4H3gJ42telWtDx00KsRyLWYYxlvm2XTYjgw1FNWxvU5bG8xqRNjHWmjguY+KjsKGwnENGUTT7rCM
      ARM59SwFqig08BYMzGpVZT82fMnNfcLK3/HEb/Qa00m3DiUJ162UAywfoDdlHxYObRXaQagBYDi4iyDcrRBqcA/pTjjAMShj4QUSYutXJrE3gy8Lekf9qy/xPH4CmwHJwp
      uqVoeuO9q3EXK1FZj77LPRiAfkik8n0J4659n1cOmgoraYk2seiQeO8GFnBjPaoY6UlNVzTEIUBYac/GwasLzjOJB50frFqhVPOR9mqCsguTu9tUgYAXvfJYLTBm93Ib0D
      1WS7F0iXV4KbFUBlU/JTc7xeryR10urg9C9NezwVo5JKdVxVIHzJxYs9IUxqXvSp9SJid27dtY+qYAJp6Z7agurdBpNswNi7ANtKH1WEUNnVch6Tut4yV9QrE2Cbgl/TNe
      XXAOShPwak4rd7SPOawOq0KiaEPzWN778l66QoUMy8VZH5pqri5hptSbKHsJRZdlGG3VjtlydxKLjrAaj/lwjoHXfJtKk8cA9oD2Jo9N0DgK6LrQ03aLbk5EtU+w1X/hSg
      FIn8QhzxzGPTqvcUv6l/Jd9W3Uua18NfqXcJRXyyANWjYbMDEcERERERFxn0DM/CWAH7G6lBAR0RX/Afj1AYCH19fX3wH45I4Firgf4Kurq8+ImR8C+B7Ao7uWKOJe4F8A
      v921EBEREREREREREVsKWcTNHOdP7TW024LIlMiyS7VJYpD1yGrheghe9x5qRT21zlcr/1kTreP8gq3dQx1ly+TjXPV39K+qLqrqiISl2qCvLMJ/pRphG7GN1Q32U511ZU
      REe0PWpUuhHcFUcd68KMTR9RmAb2Tjxj7MwvKczEs4Pghs28C6gCos4+ULw25KY9js51vIZ60gTrWPlLXI5Fwp33OrPyue2UC6TICbrWfVbhuWa2p5mM2ex+r3XNxmZR3n
      Su61rfXW/cgHkr03tm1gLWD20lVW6xSyI0j1mcqTP4JVlixudAIg8VSljoXuUFxT9Ya/feE5lHV7ClNvXroGg2Ah8jyF0WOi5NPuOyOiEcx9yTQD4Z0IzQjAZAjXPwQ+Ym
      YM/emJHLL7BGZg2ZWdKZsdwu8ctC9hSmxdA2ReWQ/5XdUczdS5op/oBmRe4jGC0eW1Z3CVIs9MaKq6sBXZafkKxwLr67ljmE237+SzC6nPaouhx8C2WaxqY+orLPcuFlWb
      uMgU5indd5BfoP3rjkae416QQZPB6DKEFdmDu1r23NpEWgxwrd7YuoElmMI8iba1WsA8lQncJbyJog9BDrPxNZPY6ri+ezMkNioVzwl6lP1K/JWKrLnVnMPIP2VTA7+pzS
      CtcVu7dEJQYvlmlTkz/6C2rueQncfMfAJjWWZYuo0Spm59IVat2k93Jm0FVv/cM+FXMvNjLAekrz68cMh6tt4NEJmmWLqklIhmSp6Kny1PhVzaRqrvCCbWmqr+tvwjbG6X
    UXtsYYx1a2B5c4wcV7ta0jsWC4A/N7fB693vGOsOkMkfWMDsu8vvVpz7AdrEQ+HOGUZsM4YeB9FiRWwEcWBFbAT/A0EgOACsUroGAAAAAElFTkSuQmCC'
    $logoBitmap = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage
    $logoBitmap.BeginInit()
    $logoBitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($logobase64)
    $logoBitmap.EndInit()
    $logoBitmap.Freeze()

    $uiHash.imgLogo.source = $logoBitmap
    
    $imageBse64 = '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
      npnNRVke8mNsyvMsW6afVJxZG0i7VL7P4P8Otpv5/+3t7fCOiH14pvfHTCN9QZsgvNLinPZH/J5WHcs3vJeRXvd9PpNp0p66si3nHPjo/p9p5v/sO32eTEr4sOxY7SbHVMpQ9zP9VN4jr/TfqB1n/67wSh8f1vlsDiAeZeT9J+89i
      tb4P4XNmG/p5/lugO2xYfbr7Jv0vXw3GI0V+T6a/T/HkPRVliXLO6vvEo+irfyPL/Ft9rWeTn8v6ONJjrXZ92bzUdaD/Hp7yPE802TM6TbpZJlu+Tvor9rK/6WyUb4Dlm37e3v3Ne0k/cD7BGnRpnjmFP9nPMYk8iLNXr4lPer8r5
      RSSimlnlOX2ufNdO9lL/nWlOsgl7BhfRvNvmv699RftfZ5tT+sOdSayWzNeo3S/31tI7/zR9/8S2shrJv082soyznqR/zjMbu/lN7oepbXLK1RvybubM1pVua/iv2y3PsjX9Y88pz2wjO5zp5tJPdeOWcNl3s5JrB3sya82zrLmeu
      JdY/1Ztaa+rpShfc61r1MK21Xx/QZkFdeox6nxHol90mXve6lMp+j7pdsb6P+z1obtmY/vms09le83Mct6COs860JP1Yv7JdjXv+3IfchEHsZdcy1yrRVptnzGtm3/xNBnNH9kf9HZT5Hff4/xf8Zf/b+kHbinL0Zjvgz/8lYE35q
      vfqcl3sC+HpUp/RBt09ez/LKsNE+E/ezP3OdeY/KfK628H/fRymfUKY8LzHWMX4yltGe14afUi/CGDf4jwAb074Qc233fx9zco/ymP/5fyLzKPX73f+zMp+rY/7PuR079H6SdS318Sl9g7+Iyzy2Vfgxu2cYtuT9OudhxnDiYue0N
      Xud+DP3KI+Vg39r8SFtJ23KntnI/6Myn/MuyH5b1il9R9/OumKP0VhF3Eyv59f92fvBmnDCluqVYdSDuaT7N+fy0TcYz/fnRnn1MNpA34tMGxM/856Vufe1S2hpvUA9vvS/UkoppZRSSimllFJKXU07ERERERERERERERERERERER
      EREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREZE75B+Hl45q2TuOnAAAA8tta0JU+s7K/gB/pL8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHic7ZmBjeIwEEW3BEqgBEqghC2BEiiBEiiBEiiBEihhS6CD3I0US5+5sWPHJLCn96Qn3SWMY88ktpP9+gIAAAAAAAAAgN/MbRgG8/zXNa53Hq9nXhqu+S1xtyDu7M6rdm6X
      udZ+7MfP8IzFHRpzcij0IdevlvaXQMe7xvVuLs/7yuveXdxUuxHR/aZx99GpmBynij4oa+W8xNp98XWqye8+yF2p3b1oz9hDzvln7jwe28rxnYvJzR2erbu2qfeTP1fb7pK8u/6Dy33EtbH+/pzW81E5zoO0d+rITalfn8An1L+U3
      23w+9b6Gxc5X7Pm6JzzjvrrPDH1fPTEvrP++kxuKuqme7RSu1E7ujbX1P8ov/9eqf5Wq2iuM+4T/Z4bm6t/WrvaR1xG86E1ifbadk88pH+lXLY8/1Prrq4XP505qK2/33M8xvHqsVyeemLTOa3/rrLPc9B8bOTfUZ79Mzi3/lPrv+
      XlNOrfB3r3aLX117ntMjzPh5qHaK7siU3ntP46j/SMPcLno7Qup3Gle6O1/jbWw/D8HBwnYjVXxyBfveON0L3mNfM7zZOOoSfWSMe1/kvuWX3bur/T/uu40rxVW/8cuXdNe8bTfuk4/DsH9NwDNbms2ZvqnKzj6Ik10vFbps32EZe
      J8qHH0n41HdM5a079Lf5ayE0O3Zvk7pu5453zGyOqVU9s7rjl+17R5hyi/uq71nmsVULfvXr2f3No/WYQ8Rvrb2yGvvfeHLn+prU+Pa8JfX9du/6vaLOmDR1vbr+ZWyd7Yo1c/Zcilw9d7xN+3l27/n7/OYeafukePffM6Xqke7ie
      WONT6m/491V/P7+6/rbO5L7taF6XXv/1+TT8e7p/f9X9aE+sEdXf2mjdL9VSyofep9H9+Or6p+vZXuc4jvkwrL//N/z8Z3HWP/9Nz9e3NzbKd+rz0t///Dn9HhQ9l6+uf7Tm+Dyu8f6v/fFzYOKRyUlvrI41HTvPyGUt+q5dOt8aO
      9VuDps/LXcn0f6/fdHYW/u1GWul/an9+8Oc2NQ3v9ba+KNvZQAAAAAAAAAAAAAA8B9gfwNARERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERE
      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
      REREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREfGG/AAhLibBalzbeAAAyGGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ
      2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4KPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNS4zLWMwMTEgNjYuMTQ1NjYxLCAyMDEyLzAyLz
      A2LTE0OjU2OjI3ICAgICAgICAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICA
      gICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iPgogICAgICAgICA8eG1wOkNyZWF0b3JUb29sPkFkb2JlIEZpcmV3b3JrcyBDUzYgKFdpbmRvd3MpPC94bXA6Q3JlYXRvclRvb2w+CiAgICAg
      ICAgIDx4bXA6Q3JlYXRlRGF0ZT4yMDE3LTAxLTMxVDE5OjQ2OjM4WjwveG1wOkNyZWF0ZURhdGU+CiAgICAgICAgIDx4bXA6TW9kaWZ5RGF0ZT4yMDE3LTAyLTA1VDEwOjM3OjMxWjwveG1wOk1vZGlmeURhdGU+CiAgICAgIDwvc
      mRmOkRlc2NyaXB0aW9uPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iPgogICAgICAgICA8ZGM6Zm9ybWF0Pm
      ltYWdlL3BuZzwvZGM6Zm9ybWF0PgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      IAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI
      CAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
      AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICA
      gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgI
      CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC
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
        Start-Sleep -Milliseconds 500
        $runspaceHash.PowerShell.EndInvoke($runspaceHash.Handle)
        $runspaceHash.PowerShell.Dispose()
        $runspaceHash.Clear()
        $uiHash.Window.DialogResult = $false
    })
    $uiHash.butInput.Add_Click({
        $folder = Select-FolderDialog -Title 'Select the Input Folder' 
        $uiHash.txtBoxInputFolder.Text = $folder
        if($uiHash.txtBoxInputFolder.Text.Length -ne 1)
        {
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
        if($uiHash.txtBoxOutputFolder.Text.Length -ne 1)
        {
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
    
    $uiHash.butSelectmp3.Add_Click({
        $uiHash.imagePath = ''
        $uiHash.textBoxArtistName.Text = ' '
        $uiHash.textBoxTrackTitle.Text = ' '
        $uiHash.textBoxAlbumTitle.Text = ' '
        $uiHash.textBoxTrackNumber.Text = ' '
        $uiHash.textBoxYear.Text = ' '
        $uiHash.textBoxComments.Text = ' '
        $uiHash.textBoxGenre.Text = ' '
        $uiHash.textBoxBPM.Text = ''
        $uiHash.tempDirectory = 'C:\'
        if($uiHash.file)
        {
          $uiHash.file.Split('\')
          $uiHash.tempDirectory = Split-Path  -Path $uiHash.file
        }
        $uiHash.file = Select-FileDialog -Title 'Select a .mp3 file' -Directory  $uiHash.tempDirectory -Filter 'MP3 (*.mp3)| *.mp3'
        $ts = New-TimeSpan -Minutes $uiHash.sliderTrackTime.Value
       

        $outfile1 = $uiHash.file.Split('\')
        $Outfilename1 = $outfile1[$outfile1.Count-1]
        $uiHash.textMP3.Text = $Outfilename1

        $shell = New-Object -ComObject Shell.Application
        $folder = Split-Path -Path $uiHash.file
        $file = Split-Path -Path $uiHash.file -Leaf
        $shellfolder = $shell.Namespace($folder)
        $shellfile = $shellfolder.ParseName($file)
        $uiHash.fileName = 'C:\mp3tools\images\' + $Outfilename1 + '.png'
        
        If(Test-Path -Path $uiHash.fileName)
        {
          $uiHash.imageWaveForm.Dispatcher.Invoke('Normal',[action]{
              $uiHash.imageWaveForm.Source = $uiHash.fileName
          })
        }
        else
        {
          $uiHash.wave = New-Object -TypeName WaveFormRendererLib.WaveFormRenderer
          $uiHash.waveSettings = New-Object -TypeName WaveFormRendererLib.SoundCloudOriginalSettings
          $uiHash.peaks = New-Object -TypeName WaveFormRendererLib.SamplingPeakProvider -ArgumentList (128)
          
          $uiHash.waveSettings.Width = '545'
          $uiHash.waveSettings.BottomHeight = '25'
          $uiHash.tempPic  = $uiHash.wave.Render($uiHash.file,$uiHash.peaks,$uiHash.waveSettings)
        
          $uiHash.tempPic.Save($uiHash.fileName)
                 
          $uiHash.imageWaveForm.Dispatcher.Invoke('Normal',[action]{
              $uiHash.imageWaveForm.Source = $uiHash.fileName
          })
        }
        $uiHash.media = [TagLib.File]::Create((Resolve-Path -Path $uiHash.file))
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
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
                     
        $uiHash.textLength.Text = $uiHash.media.Properties.Duration# $shellfolder.GetDetailsOf($shellfile, 27)
        $uiHash.textMp3Bitrate.Text = $uiHash.media.Properties.AudioBitrate # $shellfolder.GetDetailsOf($shellfile, 28)
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
        $shell.dispose()
    })
    $uiHash.buttonSelectTagPic.Add_Click({
        $uiHash.imagePath = Select-FileDialog -Title 'Select an image' -Directory 'C:\' -Filter 'All Files (*.*)| *.*'
     
        $image1 = [convert]::ToBase64String((Get-Content -Path $uiHash.imagePath -Encoding byte))
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
        $uiHash.mp3reader.close()
        $uiHash.waveOut.Close()
        
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = 'Saving Tags...'
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'White'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            #$uiHash.outputBox.Inlines.Add((New-Object System.Windows.Documents.LineBreak)) 
        })
       
        $uiHash.media = [TagLib.File]::Create((Resolve-Path -Path $uiHash.file))
        $uiHash.media.Tag.Artists = $uiHash.textBoxArtistName.Text
        $uiHash.media.Tag.Title = $uiHash.textBoxTrackTitle.Text
        $uiHash.media.Tag.Album = $uiHash.textBoxAlbumTitle.Text
        $uiHash.media.Tag.Track = $uiHash.textBoxTrackNumber.Text
        $uiHash.media.Tag.Year = $uiHash.textBoxYear.Text
        $uiHash.media.Tag.Genres = $uiHash.textBoxGenre.Text
        $uiHash.media.Tag.Comment = $uiHash.textBoxComments.Text
        if($uiHash.imagePath.Length -ne 0)
        {
          $pic = [taglib.picture]::createfrompath($uiHash.imagePath) 
          $uiHash.media.Tag.Pictures = $pic
        }
        try
        {
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
        }
        catch
        {
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = $_
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
    })
    $uiHash.buttonPlay.Add_Click({
        $uiHash.waveOut = New-Object -TypeName NAudio.Wave.WaveOut
        $uiHash.mp3Reader = New-Object -TypeName NAudio.Wave.Mp3FileReader -ArgumentList ($uiHash.file)
        $uiHash.mp3Reader.CurrentTime = New-Object -TypeName System.TimeSpan -ArgumentList (0, 0, 0, $uiHash.sliderTrackTime.Value, 0)
        $uiHash.waveOut.Init($uiHash.mp3Reader) 
       
        $uiHash.waveOut.Volume = 0.8
        $uiHash.sliderVolume.Value = $uiHash.waveOut.Volume
        $uiHash.sliderSpeed.Value = 0
        if($uiHash.file.length -ne 0)
        {
          $uiHash.waveOut.Play()
          
          $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
              $message = 'Playback of ' + $uiHash.textMP3.Text + ' - Started @ ' + $uiHash.mp3Reader.CurrentTime
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
        $uiHash.waveOut.Stop()
        $uiHash.mp3Reader.Close()
        # $uiHash.mp3Reader.Dispose()
          
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = ' - ' + $uiHash.waveOut.PlaybackState   
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Yellow'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            $uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
        
        $uiHash.waveOut.Close()
        $uiHash.waveOut.Dispose()
    })
    $uiHash.sliderTrackTime.Add_ValueChanged({
        $uiHash.mp3Reader.CurrentTime = New-Object -TypeName System.TimeSpan -ArgumentList (0, 0, 0, $uiHash.sliderTrackTime.Value, 0)
        $uiHash.outputBox.Inlines.RemoveAt($uiHash.outputBox.Inlines.Count -1)
           
        $uiHash.outputBox.Dispatcher.Invoke('Normal',[action]{
            $message = ' ▸ ' + $uiHash.mp3Reader.CurrentTime  
            $Run = New-Object -TypeName System.Windows.Documents.Run
            $Run.Foreground = 'Yellow'
            $Run.Text = $message
            $uiHash.outputBox.Inlines.Add($Run)
            #$uiHash.outputBox.Inlines.Add((New-Object -TypeName System.Windows.Documents.LineBreak)) 
        })
        $uiHash.scrollviewer.Dispatcher.Invoke('Normal',[action]{
            $uiHash.scrollviewer.ScrollToEnd()
        })
    })
    
    $uiHash.sliderVolume.Add_ValueChanged({
        $uiHash.waveOut.Volume = $uiHash.sliderVolume.Value
    })
    #endregion
    
    $null = $uiHash.Window.ShowDialog()
    $Runspace.Close()
    $Runspace.Dispose()
})

$psCmd.Runspace = $newRunspace
$null = $psCmd.BeginInvoke()