using System; // For core types like TimeSpan
using System.Linq; // For LINQ operations
using System.Management.Automation; // For Cmdlet and PowerShell-related functionality
using Vanara.Windows.Shell; // For WallpaperManager and related types

[Cmdlet(VerbsCommon.Get, "Slideshow")]
[OutputType(typeof(WallpaperManager.WallpaperSlideshow))]
public class GetSlideshowCmdlet : PSCmdlet
{
    protected override void ProcessRecord()
    {
        base.ProcessRecord();

        try
        {
            // Retrieve the current slideshow configuration
            var slideshowInfo = WallpaperManager.Slideshow;

            if (slideshowInfo == null)
            {
                WriteWarning("No slideshow configuration is currently active.");
                return;
            }

            // Enhance the original object with the ImageFolder property
            var enhancedSlideshow = new PSObject(slideshowInfo);
            string imageFolder =
                slideshowInfo.Images?.FirstOrDefault()?.FileSystemPath ?? string.Empty;

            // Add the ImageFolder property dynamically
            enhancedSlideshow.Properties.Add(new PSNoteProperty("ImageFolder", imageFolder));

            // Optionally remove the Images property for clarity
            var imagesProperty = enhancedSlideshow.Properties["Images"];
            if (imagesProperty != null)
            {
                enhancedSlideshow.Properties.Remove(imagesProperty.Name);
            }

            // Write the enhanced object to the pipeline
            WriteObject(enhancedSlideshow);
        }
        catch (Exception ex)
        {
            // Write an error if something goes wrong
            WriteError(new ErrorRecord(ex, "GetSlideshowError", ErrorCategory.NotSpecified, null));
        }
    }
}
