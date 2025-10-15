// Copyright 2021 satinxs
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// NOTE: took it from https://github.com/satinxs/comptrie.zig

pub fn CompTrie(comptime V: type) type {
    const TrieNode = struct {
        const Self = @This();
        value: ?V = null,
        children: [256]?*Self = [_]?*Self{null} ** 256,
    };

    return struct {
        const Self = @This();

        root: ?*TrieNode = null,

        pub fn put(self: *Self, key: []const u8, value: V) void {
            if (self.root == null) {
                var rootNode = TrieNode{};
                self.root = &rootNode;
            }

            var node = self.root.?;

            for (key) |c| {
                if (node.children[c]) |n| {
                    node = n;
                } else {
                    var trieNode = TrieNode{};
                    node.children[c] = &trieNode;
                    node = node.children[c].?;
                }
            }

            node.value = value;
        }

        pub fn get(self: *const Self, key: []const u8) ?V {
            var node: *TrieNode = self.root.?;

            for (key) |c| {
                if (node.children[c]) |n| {
                    node = n;
                } else {
                    return null;
                }
            }

            return node.value;
        }
    };
}

fn buildTestTrie() CompTrie(u32) {
    var trie = CompTrie(u32){};

    trie.put("await", 0);
    trie.put("async", 1);
    trie.put("awaitable", 2);
    trie.put("wait", 3);

    return trie;
}

test "Get correctly gets inserted elements" {
    const std = @import("std");
    const testing = std.testing;

    var trie = comptime buildTestTrie();

    try testing.expect(trie.get("await") == @as(u32, 0));
    try testing.expect(trie.get("async") == @as(u32, 1));
    try testing.expect(trie.get("awaitable") == @as(u32, 2));
    try testing.expect(trie.get("wait") == @as(u32, 3));
}

test "Get returns null when partial or no match is found" {
    const std = @import("std");
    const testing = std.testing;

    var trie = comptime buildTestTrie();

    try testing.expect(trie.get("awit") == null);
    try testing.expect(trie.get("asinc") == null);
    try testing.expect(trie.get("table") == null);
    try testing.expect(trie.get("aws") == null);
}
