function localName(name) {
    var index = String(name || "").lastIndexOf(":");
    return index === -1 ? String(name || "") : String(name).slice(index + 1);
}

function xmlCodePoint(code) {
    return code === 0x9 || code === 0xa || code === 0xd
        || (code >= 0x20 && code <= 0xd7ff)
        || (code >= 0xe000 && code <= 0xfffd)
        || (code >= 0x10000 && code <= 0x10ffff);
}

function isXmlWhitespace(character) {
    return character === " " || character === "\t"
        || character === "\r" || character === "\n";
}

function skipXmlWhitespace(source, cursor) {
    while (cursor < source.length && isXmlWhitespace(source[cursor]))
        cursor++;
    return cursor;
}

function onlyXmlWhitespace(source) {
    for (var index = 0; index < source.length; index++) {
        if (!isXmlWhitespace(source[index]))
            return false;
    }
    return true;
}

function validXmlString(source) {
    for (var index = 0; index < source.length; index++) {
        var first = source.charCodeAt(index);
        if (first >= 0xd800 && first <= 0xdbff) {
            if (index + 1 >= source.length)
                return false;
            var second = source.charCodeAt(index + 1);
            if (second < 0xdc00 || second > 0xdfff)
                return false;
            var code = 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00;
            if (!xmlCodePoint(code))
                return false;
            index++;
        } else if ((first >= 0xdc00 && first <= 0xdfff) || !xmlCodePoint(first)) {
            return false;
        }
    }
    return true;
}

function fromCodePoint(code) {
    if (!xmlCodePoint(code))
        throw new Error("invalid XML code point");
    if (code <= 0xffff)
        return String.fromCharCode(code);
    code -= 0x10000;
    return String.fromCharCode(0xd800 + (code >> 10), 0xdc00 + (code & 0x3ff));
}

function decodeEntities(value) {
    var source = String(value || "");
    var output = "";
    var cursor = 0;

    while (cursor < source.length) {
        var amp = source.indexOf("&", cursor);
        if (amp === -1) {
            output += source.slice(cursor);
            break;
        }
        output += source.slice(cursor, amp);
        var semi = source.indexOf(";", amp + 1);
        if (semi === -1)
            throw new Error("unterminated entity");

        var entity = source.slice(amp + 1, semi);
        var named = {
            lt: "<",
            gt: ">",
            amp: "&",
            quot: "\"",
            apos: "'"
        };
        if (Object.prototype.hasOwnProperty.call(named, entity)) {
            output += named[entity];
        } else {
            var match = entity.match(/^#([0-9]+)$/);
            var radix = 10;
            if (!match) {
                match = entity.match(/^#x([0-9a-fA-F]+)$/);
                radix = 16;
            }
            if (!match)
                throw new Error("unknown entity");
            output += fromCodePoint(parseInt(match[1], radix));
        }
        cursor = semi + 1;
    }

    return output;
}

function nameAt(source, cursor) {
    var match = source.slice(cursor).match(/^[A-Za-z_][A-Za-z0-9_.:-]*/);
    if (!match)
        throw new Error("invalid XML name");
    return { name: match[0], next: cursor + match[0].length };
}

function tagEnd(source, cursor) {
    var quote = "";
    for (var index = cursor; index < source.length; index++) {
        var character = source[index];
        if (quote) {
            if (character === quote)
                quote = "";
        } else if (character === "\"" || character === "'") {
            quote = character;
        } else if (character === ">") {
            return index;
        } else if (character === "<") {
            throw new Error("nested tag opener");
        }
    }
    throw new Error("unterminated tag");
}

function parseAttributes(content, cursor, decodeValues) {
    var attributes = {};
    var ordered = [];

    if (cursor < content.length && !isXmlWhitespace(content[cursor]))
        throw new Error("attribute without XML whitespace");
    cursor = skipXmlWhitespace(content, cursor);
    while (cursor < content.length) {
        var parsedAttribute = nameAt(content, cursor);
        var attributeName = parsedAttribute.name;
        cursor = parsedAttribute.next;
        cursor = skipXmlWhitespace(content, cursor);
        if (content[cursor] !== "=")
            throw new Error("attribute without value");
        cursor++;
        cursor = skipXmlWhitespace(content, cursor);

        var quote = content[cursor];
        if (quote !== "\"" && quote !== "'")
            throw new Error("unquoted attribute");
        var end = content.indexOf(quote, cursor + 1);
        if (end === -1)
            throw new Error("unterminated attribute");
        if (Object.prototype.hasOwnProperty.call(attributes, attributeName))
            throw new Error("duplicate attribute");

        var raw = content.slice(cursor + 1, end);
        if (raw.indexOf("<") !== -1)
            throw new Error("tag opener in attribute");
        attributes[attributeName] = decodeValues ? decodeEntities(raw) : raw;
        ordered.push({ name: attributeName, value: raw });
        cursor = end + 1;
        if (cursor < content.length && !isXmlWhitespace(content[cursor]))
            throw new Error("adjacent attributes");
        cursor = skipXmlWhitespace(content, cursor);
    }

    return { attributes: attributes, ordered: ordered };
}

function startTag(content) {
    var parsedName = nameAt(content, 0);
    var parsedAttributes = parseAttributes(content, parsedName.next, true);
    return { name: parsedName.name, attributes: parsedAttributes.attributes };
}

function validateXmlDeclaration(content) {
    var target = nameAt(content, 0);
    if (target.name !== "xml")
        throw new Error("invalid XML declaration target");
    var parsed = parseAttributes(content, target.next, false);
    var fields = parsed.ordered;
    if (fields.length < 1 || fields.length > 3
            || fields[0].name !== "version"
            || fields[0].value !== "1.0")
        throw new Error("invalid XML declaration");

    var cursor = 1;
    if (cursor < fields.length && fields[cursor].name === "encoding") {
        if (!/^[A-Za-z][A-Za-z0-9._-]*$/.test(fields[cursor].value))
            throw new Error("invalid XML encoding");
        cursor++;
    }
    if (cursor < fields.length && fields[cursor].name === "standalone") {
        if (fields[cursor].value !== "yes" && fields[cursor].value !== "no")
            throw new Error("invalid XML standalone value");
        cursor++;
    }
    if (cursor !== fields.length)
        throw new Error("invalid XML declaration order");
}

function validateProcessingInstruction(content) {
    var target = nameAt(content, 0);
    if (target.name.toLowerCase() === "xml")
        throw new Error("reserved processing instruction target");
    if (target.next < content.length && !isXmlWhitespace(content[target.next]))
        throw new Error("processing instruction target separator");
}

function parseXml(source) {
    var text = String(source || "");
    if (text[0] === "\ufeff")
        text = text.slice(1);
    if (!validXmlString(text))
        throw new Error("invalid raw XML code point");
    var roots = [];
    var stack = [];
    var cursor = 0;
    var declarationSeen = false;

    function appendText(value, decode) {
        if (decode && value.indexOf("]]>") !== -1)
            throw new Error("CDATA terminator in character data");
        var body = decode ? decodeEntities(value) : value;
        if (stack.length)
            stack[stack.length - 1].children.push(body);
        else if (!onlyXmlWhitespace(body))
            throw new Error("text outside root");
    }

    while (cursor < text.length) {
        var opener = text.indexOf("<", cursor);
        if (opener === -1) {
            appendText(text.slice(cursor), true);
            cursor = text.length;
            break;
        }
        appendText(text.slice(cursor, opener), true);

        if (text.slice(opener, opener + 4) === "<!--") {
            var commentEnd = text.indexOf("-->", opener + 4);
            var comment = commentEnd === -1 ? "" : text.slice(opener + 4, commentEnd);
            if (commentEnd === -1 || comment.indexOf("--") !== -1
                    || (comment.length && comment[comment.length - 1] === "-"))
                throw new Error("malformed comment");
            cursor = commentEnd + 3;
            continue;
        }
        if (text.slice(opener, opener + 9) === "<![CDATA[") {
            if (!stack.length)
                throw new Error("CDATA outside root");
            var cdataEnd = text.indexOf("]]>", opener + 9);
            if (cdataEnd === -1)
                throw new Error("unterminated CDATA");
            appendText(text.slice(opener + 9, cdataEnd), false);
            cursor = cdataEnd + 3;
            continue;
        }
        if (text.slice(opener, opener + 2) === "<!") {
            throw new Error("declarations are not accepted");
        }
        if (text.slice(opener, opener + 2) === "<?") {
            var instructionEnd = text.indexOf("?>", opener + 2);
            if (instructionEnd === -1)
                throw new Error("unterminated processing instruction");
            var instruction = text.slice(opener + 2, instructionEnd);
            var instructionTarget = nameAt(instruction, 0);
            if (instructionTarget.name.toLowerCase() === "xml") {
                if (opener !== 0 || declarationSeen || roots.length || stack.length)
                    throw new Error("misplaced XML declaration");
                validateXmlDeclaration(instruction);
                declarationSeen = true;
            } else {
                validateProcessingInstruction(instruction);
            }
            cursor = instructionEnd + 2;
            continue;
        }

        var end = tagEnd(text, opener + 1);
        var body = text.slice(opener + 1, end);
        if (body[0] === "/") {
            var closing = body.slice(1);
            var parsedClosing = nameAt(closing, 0);
            var closingEnd = skipXmlWhitespace(closing, parsedClosing.next);
            if (closingEnd !== closing.length || !stack.length
                    || stack[stack.length - 1].name !== parsedClosing.name)
                throw new Error("unbalanced XML");
            stack.pop();
            cursor = end + 1;
            continue;
        }

        var selfClosing = body.length > 0 && body[body.length - 1] === "/";
        if (selfClosing)
            body = body.slice(0, body.length - 1);
        var tag = startTag(body);
        var node = {
            name: tag.name,
            local: localName(tag.name),
            attributes: tag.attributes,
            children: []
        };
        if (stack.length)
            stack[stack.length - 1].children.push(node);
        else
            roots.push(node);
        if (!selfClosing)
            stack.push(node);
        cursor = end + 1;
    }

    if (stack.length || roots.length !== 1)
        throw new Error("invalid XML document");
    return roots[0];
}

function attribute(node, name) {
    for (var key in node.attributes) {
        if (localName(key) === name)
            return node.attributes[key];
    }
    return "";
}

function directElement(node, name) {
    for (var index = 0; index < node.children.length; index++) {
        var child = node.children[index];
        if (child && typeof child === "object" && child.local === name)
            return child;
    }
    return null;
}

function directText(node) {
    var output = "";
    for (var index = 0; index < node.children.length; index++) {
        if (typeof node.children[index] === "string")
            output += node.children[index];
    }
    return output.trim();
}

function encodePath(path) {
    return String(path).split("/").map(function (part) {
        return encodeURIComponent(part);
    }).join("/");
}

function localFile(href) {
    var source = String(href || "");
    if (/[\u0000-\u001f\u007f]/.test(source)
            || source.slice(0, 5).toLowerCase() !== "file:")
        return null;

    var remainder = source.slice(5);
    var authority = "";
    var pathAndSuffix = remainder;
    if (remainder.slice(0, 2) === "//") {
        var authorityEnd = remainder.slice(2).search(/[/?#]/);
        if (authorityEnd === -1) {
            authority = remainder.slice(2);
            pathAndSuffix = "";
        } else {
            authority = remainder.slice(2, authorityEnd + 2);
            pathAndSuffix = remainder.slice(authorityEnd + 2);
        }
        if (authority.length && authority.toLowerCase() !== "localhost")
            return null;
    }

    var suffix = pathAndSuffix.search(/[?#]/);
    var encodedPath = suffix === -1 ? pathAndSuffix : pathAndSuffix.slice(0, suffix);
    if (!encodedPath.length || encodedPath[0] !== "/")
        return null;

    var path;
    try {
        path = decodeURIComponent(encodedPath);
    } catch (error) {
        return null;
    }
    if (!path.length || path[0] !== "/" || /[\u0000-\u001f\u007f]/.test(path))
        return null;

    try {
        return {
            path: path,
            uri: "file://" + encodePath(path)
        };
    } catch (error) {
        return null;
    }
}

function parsedTimestamp(value) {
    var timestamp = Date.parse(String(value || ""));
    return isNaN(timestamp) ? 0 : timestamp;
}

function basename(path) {
    var clean = String(path || "").replace(/\/+$/, "");
    var index = clean.lastIndexOf("/");
    return clean.slice(index + 1);
}

function parseXbel(text) {
    var root;
    try {
        root = parseXml(text);
    } catch (error) {
        return [];
    }
    if (!root || root.local !== "xbel")
        return [];

    var rows = [];
    var indexes = {};
    for (var index = 0; index < root.children.length; index++) {
        var bookmark = root.children[index];
        if (!bookmark || typeof bookmark !== "object" || bookmark.local !== "bookmark")
            continue;

        var file = localFile(attribute(bookmark, "href"));
        if (!file)
            continue;
        var titleNode = directElement(bookmark, "title");
        var title = titleNode ? directText(titleNode) : "";
        var row = {
            uri: file.uri,
            path: file.path,
            title: title || basename(file.path),
            modified: parsedTimestamp(attribute(bookmark, "modified"))
        };

        var key = "$" + file.uri;
        if (!Object.prototype.hasOwnProperty.call(indexes, key)) {
            indexes[key] = rows.length;
            rows.push(row);
        } else {
            var prior = indexes[key];
            if (row.modified > rows[prior].modified)
                rows[prior] = row;
        }
    }
    return rows;
}

function sortRecent(rows, limit) {
    var source = Array.isArray(rows) ? rows : [];
    var cap = limit === undefined ? 40 : Math.max(0, Math.floor(Number(limit) || 0));
    return source.map(function (row, index) {
        return { row: row, index: index };
    }).sort(function (left, right) {
        var delta = Number(right.row.modified || 0) - Number(left.row.modified || 0);
        return delta || left.index - right.index;
    }).slice(0, cap).map(function (entry) {
        return entry.row;
    });
}

function filterExisting(rows, paths) {
    var existing = {};
    var records = Array.isArray(paths) ? paths : [];
    for (var index = 0; index < records.length; index++)
        existing["$" + records[index]] = true;
    return (Array.isArray(rows) ? rows : []).filter(function (row) {
        return row && existing["$" + row.path] === true;
    });
}

function parentUri(path) {
    var value = String(path || "");
    if (!value.length || value[0] !== "/")
        return "";
    var clean = value.length > 1 ? value.replace(/\/+$/, "") : value;
    var slash = clean.lastIndexOf("/");
    var parent = slash <= 0 ? "/" : clean.slice(0, slash);
    return "file://" + encodePath(parent);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        filterExisting: filterExisting,
        parentUri: parentUri,
        parseXbel: parseXbel,
        sortRecent: sortRecent
    };
}
