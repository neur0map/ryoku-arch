
function getIconForMime(mimeType, content) {
    if (!mimeType) return "";
    
    if (mimeType === "text/plain" && content) {
        var urlMatch = content.match(/^https?:\/\/[^\s]+/);
        if (urlMatch) {
            try {
                var url = new URL(content.trim());
                return url.origin + "/favicon.ico";
            } catch (e) {
            }
        }
    }
    
    if (mimeType.startsWith("image/")) {
        return "image";
    }
    
    if (mimeType.startsWith("text/") || mimeType === "application/json" || 
        mimeType === "application/xml" || mimeType === "application/javascript") {
        return "text";
    }
    
    if (mimeType === "text/uri-list") {
        return "file";
    }
    
    if (mimeType.startsWith("video/")) {
        return "video";
    }
    
    if (mimeType.startsWith("audio/")) {
        return "audio";
    }
    
    if (mimeType.match(/zip|tar|gz|bz2|xz|7z|rar/)) {
        return "archive";
    }
    
    if (mimeType === "application/pdf") {
        return "pdf";
    }
    
    return "file";
}

function isUrl(text) {
    if (!text) return false;
    var trimmed = text.trim();
    return /^https?:\/\/[^\s]+/.test(trimmed);
}

function getGoogleFaviconUrl(domain) {
    if (!domain) return "";
    return "https://www.google.com/s2/favicons?domain=" + encodeURIComponent(domain) + "&sz=64";
}

function getFaviconUrl(text) {
    if (!text) return "";
    try {
        var trimmed = text.trim();
        var url = new URL(trimmed);
        return url.origin + "/favicon.ico";
    } catch (e) {
        return "";
    }
}

function getFaviconFallbackUrl(text) {
    if (!text) return "";
    try {
        var trimmed = text.trim();
        var url = new URL(trimmed);
        return getGoogleFaviconUrl(url.hostname);
    } catch (e) {
        return "";
    }
}

function getNerdFontIconForExtension(filePath) {
    if (!filePath) return "";
    
    var ext = filePath.split('.').pop().toLowerCase();
    
    if (ext === "js" || ext === "mjs") return "󰌞";
    if (ext === "ts") return "󰛦";
    if (ext === "py") return "󰌠";
    if (ext === "java") return "󰬷";
    if (ext === "cpp" || ext === "cc" || ext === "cxx") return "󰙲";
    if (ext === "c") return "󰙱";
    if (ext === "rs") return "󱘗";
    if (ext === "go") return "󰟓";
    if (ext === "php") return "󰌟";
    if (ext === "rb") return "󰴭";
    
    if (ext === "html" || ext === "htm") return "󰌝";
    if (ext === "css") return "󰌜";
    if (ext === "json") return "󰘦";
    if (ext === "xml") return "󰗀";
    
    if (ext === "pdf") return "󰈦";
    if (ext === "doc" || ext === "docx") return "󰈬";
    if (ext === "xls" || ext === "xlsx") return "󰈛";
    if (ext === "ppt" || ext === "pptx") return "󰈧";
    if (ext === "txt") return "󰈙";
    if (ext === "md") return "󰍔";
    
    if (ext === "png" || ext === "jpg" || ext === "jpeg" || ext === "gif" || 
        ext === "bmp" || ext === "webp" || ext === "svg" || ext === "ico") return "󰈟";
    
    if (ext === "mp4" || ext === "mkv" || ext === "avi" || ext === "mov" || 
        ext === "wmv" || ext === "flv" || ext === "webm") return "󰈫";
    
    if (ext === "mp3" || ext === "wav" || ext === "flac" || ext === "ogg" || 
        ext === "m4a" || ext === "wma") return "󰈣";
    
    if (ext === "zip" || ext === "tar" || ext === "gz" || ext === "bz2" || 
        ext === "xz" || ext === "7z" || ext === "rar") return "󰛫";
    
    return "󰈔";
}

function escapeShellArg(arg) {
    if (arg === null || arg === undefined) return "''";
    return "'" + arg.toString().replace(/'/g, "'\\''") + "'";
}
