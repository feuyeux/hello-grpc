<?php declare(strict_types=1);
// filepath: /Users/han/coding/hello-grpc/hello-grpc-php/common/utils/StringUtils.php
namespace Common\Utils;

/**
 * Helper class for string operations
 */
class StringUtils
{
    /**
     * Convert a string to uppercase
     * @param string $input The input string
     * @return string The uppercase string
     */
    public static function toUpper(string $input): string
    {
        return strtoupper($input);
    }
}
