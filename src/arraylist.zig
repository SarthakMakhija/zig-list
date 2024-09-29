const std = @import("std");

pub const Error = error{
    IndexOutOfBounds,
    NoSuchElement,
};

pub fn ArrayList(comptime T: type) type {
    return struct {
        elements: []T,
        index: usize,
        size: usize,
        allocator: std.mem.Allocator,

        const DEFAULT_CAPACITY: usize = 10;

        pub fn initWithoutCapacity(allocator: std.mem.Allocator) !ArrayList(T) {
            return initWithCapacity(allocator, DEFAULT_CAPACITY);
        }

        pub fn initWithCapacity(allocator: std.mem.Allocator, capacity: usize) !ArrayList(T) {
            return .{
                .elements = try allocator.alloc(T, capacity),
                .index = 0,
                .size = 0,
                .allocator = allocator,
            };
        }

        pub fn add(self: *ArrayList(T), element: T) !void {
            if (self.index >= self.elements.len) {
                try self.grow(self.elements.len * 2);
            }
            self.elements[self.index] = element;
            self.index = self.index + 1;
            self.size = self.size + 1;
        }

        pub fn set(self: ArrayList(T), index: usize, element: T) !void {
            if (!isIndexInBounds(index, self.size)) {
                return Error.IndexOutOfBounds;
            } else {
                self.elements[index] = element;
            }
        }

        pub fn get(self: ArrayList(T), index: usize) !T {
            return if (!isIndexInBounds(index, self.size)) Error.IndexOutOfBounds else self.elements[index];
        }

        pub fn getFirst(self: ArrayList(T)) !T {
            return if (self.isEmpty()) Error.NoSuchElement else self.elements[0];
        }

        pub fn getLast(self: ArrayList(T)) !T {
            return if (self.isEmpty()) Error.NoSuchElement else self.elements[self.size - 1];
        }

        pub fn match_any(self: ArrayList(T), predicate: fn (T) bool) bool {
            for (self.elements[0..self.size]) |element| {
                if (predicate(element)) {
                    return true;
                }
            }
            return false;
        }

        pub fn match_all(self: ArrayList(T), predicate: fn (T) bool) bool {
            for (self.elements[0..self.size]) |element| {
                if (!predicate(element)) {
                    return false;
                }
            }
            return true;
        }

        pub fn isEmpty(self: ArrayList(T)) bool {
            return self.size == 0;
        }

        pub fn deinit(self: ArrayList(T)) void {
            self.allocator.free(self.elements);
        }

        fn grow(self: *ArrayList(T), new_size: usize) !void {
            const copied = try self.allocator.alloc(T, new_size);
            @memcpy(copied[0..self.elements.len], self.elements);
            self.allocator.free(self.elements);
            self.elements = copied;
        }

        fn isIndexInBounds(index: usize, bound_index: usize) bool {
            return index >= 0 and index < bound_index;
        }
    };
}

test "adds an integer to the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try std.testing.expectEqual(10, try list.get(0));
}

test "adds a few integers to the list such that the list requires a resize" {
    var list = try ArrayList(i32).initWithCapacity(std.testing.allocator, 2);
    defer list.deinit();

    try list.add(100);
    try list.add(200);
    try list.add(300);
    try list.add(400);

    try std.testing.expectEqual(100, try list.get(0));
    try std.testing.expectEqual(200, try list.get(1));
    try std.testing.expectEqual(300, try list.get(2));
    try std.testing.expectEqual(400, try list.get(3));
}

test "attempts to get an element from list at an index which is beyond the bounds of list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try std.testing.expectError(Error.IndexOutOfBounds, list.get(1));
}

test "gets the first element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try std.testing.expectEqual(10, try list.getFirst());
}

test "attempts to get the first element from an empty list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectError(Error.NoSuchElement, list.getFirst());
}

test "gets the last element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(20);
    try std.testing.expectEqual(20, try list.getLast());
}

test "attempts to get the last element from an empty list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectError(Error.NoSuchElement, list.getLast());
}

test "validates that the list is empty" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try std.testing.expect(list.isEmpty());
}

test "validates that the list is not empty" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try std.testing.expect(!list.isEmpty());
}

test "set the element at an index in the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(20);

    try list.set(1, 50);
    try std.testing.expectEqual(50, try list.get(1));
}

test "attempts to set the element at an index which is beyond the bounds of list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try std.testing.expectError(Error.IndexOutOfBounds, list.set(1, 20));
}

test "matches an element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(20);
    try list.add(45);

    try std.testing.expect(list.match_any(struct {
        fn match(element: i32) bool {
            return @rem(element, 2) == 0;
        }
    }.match));
}

test "does not match any element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(45);

    try std.testing.expectEqual(false, list.match_any(struct {
        fn match(element: i32) bool {
            return @rem(element, 2) == 0;
        }
    }.match));
}

test "matches all the elements from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(20);
    try list.add(44);

    try std.testing.expect(list.match_all(struct {
        fn match(element: i32) bool {
            return @rem(element, 2) == 0;
        }
    }.match));
}

test "does not match all the elements from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    try std.testing.expectEqual(false, list.match_all(struct {
        fn match(element: i32) bool {
            return @rem(element, 3) == 0;
        }
    }.match));
}