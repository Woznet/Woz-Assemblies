using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Utilities
{
    /// <summary>
    /// Provides methods to format file sizes into human-readable strings.
    /// </summary>
    public static class FormatLength
    {
        /// <summary>
        /// Formats a file size into a human-readable string.
        /// </summary>
        /// <param name="fileSize">The size of the file in bytes.</param>
        /// <param name="buffer">The buffer to receive the formatted string.</param>
        /// <param name="bufferSize">The size of the buffer, in characters.</param>
        /// <returns>If the function succeeds, the return value is a pointer to the buffer. Otherwise, it returns zero.</returns>
        [DllImport("Shlwapi.dll", CharSet = CharSet.Auto)]
        public static extern long StrFormatByteSize(long fileSize, StringBuilder buffer, int bufferSize);

        /// <summary>
        /// Helper method to format a file size into a human-readable string.
        /// </summary>
        /// <param name="fileSize">The size of the file in bytes.</param>
        /// <returns>A human-readable string that represents the file size.</returns>
        public static string Format(long fileSize)
        {
            // Create a StringBuilder instance with a capacity of 64 characters
            StringBuilder sb = new StringBuilder(64);
            StrFormatByteSize(fileSize, sb, sb.Capacity);
            return sb.ToString();
        }

        /// <summary>
        /// Main method for testing purposes.
        /// </summary>
        public static void Main()
        {
            long fileSize = long.MaxValue; // Very large number to test the function
            string formattedSize = Format(fileSize);
            Console.WriteLine($"Formatted size for {fileSize} bytes: {formattedSize}");
        }
    }
}
