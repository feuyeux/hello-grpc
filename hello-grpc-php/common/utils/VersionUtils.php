<?php declare(strict_types=1);
// filepath: /Users/han/coding/hello-grpc/hello-grpc-php/common/utils/VersionUtils.php
namespace Common\Utils;

/**
 * Helper class for version related functionality
 */
class VersionUtils
{
    /**
     * Get the gRPC version string
     * @return string The gRPC version string in format "grpc.version=X.Y.Z"
     */
    public static function getVersion(): string
    {
        // Check if gRPC extension is loaded
        if (!extension_loaded('grpc')) {
            return "grpc.version=unknown (extension not loaded)";
        }
        
        // Get version from reflection if possible
        $version = "unknown";
        
        // Try to get extension info without using phpinfo()
        $extensions = get_loaded_extensions();
        if (in_array('grpc', $extensions)) {
            $extension_version = phpversion('grpc');
            if ($extension_version !== false) {
                $version = $extension_version;
            }
        }
        
        return "grpc.version=" . $version;
    }
}
