using System;
using System.IO;
using System.Management.Automation;
using Vanara.Windows.Shell;

[Cmdlet(VerbsCommon.Set, "Slideshow")]
[OutputType(typeof(object))]
public class SetSlideshowCmdlet : PSCmdlet
{
    private string folderPath;
    private string currentLocationPath = string.Empty; // Initialize as empty to avoid null

    [Parameter(Mandatory = true, Position = 0)]
    [ValidateNotNullOrEmpty]
    public string FolderPath
    {
        get => folderPath;
        set
        {
            // Resolve the folder path to an absolute path
            folderPath = value;
        }
    }

    [Parameter]
    [ValidateSet("Center", "Tile", "Stretch", "Fit", "Fill", "Span", IgnoreCase = true)]
    public string Fit { get; set; } = "Fill";

    [Parameter]
    public TimeSpan Interval { get; set; } = TimeSpan.FromMinutes(10);

    [Parameter]
    public SwitchParameter NoShuffle { get; set; }

    [Parameter]
    public SwitchParameter PassThru { get; set; }

    protected override void BeginProcessing()
    {
        base.BeginProcessing();

        try
        {
            // Get the current location path from PowerShell session
            currentLocationPath = this.SessionState.Path.CurrentLocation.Path;
            WriteVerbose($"Current Location Path: {currentLocationPath}");

            // If FolderPath is not rooted, try combining with currentLocationPath
            if (!Path.IsPathRooted(folderPath))
            {
                string combinedPath = Path.Combine(currentLocationPath, folderPath);
                string resolvedPath = Path.GetFullPath(combinedPath); // Normalize the path
                WriteVerbose($"Resolved Path: {resolvedPath}");

                // Check if the resolved path is valid
                if (Directory.Exists(resolvedPath))
                {
                    folderPath = resolvedPath;
                }
                else
                {
                    throw new ArgumentException(
                        $"The provided FolderPath '{folderPath}' could not be resolved to a valid rooted path."
                    );
                }
            }
            else
            {
                // Normalize the path if it is already rooted
                folderPath = Path.GetFullPath(folderPath);
                WriteVerbose($"Normalized Path: {folderPath}");
            }
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                $"Failed to process FolderPath '{folderPath}': {ex.Message}",
                ex
            );
        }
    }

    protected override void ProcessRecord()
    {
        try
        {
            // Validate resolved folder path
            if (!Directory.Exists(FolderPath))
            {
                throw new ArgumentException($"Unable to find the directory - {FolderPath}");
            }

            // Determine Shuffle value
            bool shuffle = !NoShuffle.IsPresent;

            // Convert Fit parameter to WallpaperFit enum
            if (!Enum.TryParse(Fit, true, out WallpaperFit wallpaperFit))
            {
                throw new ArgumentException($"Invalid value for Fit: {Fit}");
            }

            // Set slideshow
            WallpaperManager.SetSlideshow(FolderPath, wallpaperFit, Interval, shuffle);

            // Return slideshow info if PassThru is specified
            if (PassThru.IsPresent)
            {
                var slideshowInfo = WallpaperManager.Slideshow;
                WriteObject(slideshowInfo);
            }
        }
        catch (Exception ex)
        {
            WriteError(
                new ErrorRecord(ex, "SetSlideshowError", ErrorCategory.NotSpecified, FolderPath)
            );
        }
    }
}
