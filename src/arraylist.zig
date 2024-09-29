const std = @import("std");

//TODO:
// addAll,
// test for ArrayList with a struct,
// check for concurrent modifications in iterator, filter
// remove,
// removeFirst,
// removeLast,
pub fn ArrayList(comptime T: type) type {
    return struct {
        elements: []T,
        index: usize,
        size: usize,
        allocator: std.mem.Allocator,

        pub const Error = error{
            IndexOutOfBounds,
            NoSuchElement,
        };

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

        pub fn matches_any(self: ArrayList(T), predicate: fn (T) bool) bool {
            for (self.elements[0..self.size]) |element| {
                if (predicate(element)) {
                    return true;
                }
            }
            return false;
        }

        pub fn matches_all(self: ArrayList(T), predicate: fn (T) bool) bool {
            for (self.elements[0..self.size]) |element| {
                if (!predicate(element)) {
                    return false;
                }
            }
            return true;
        }

        pub fn contains(self: ArrayList(T), target: T) bool {
            return self.index_of(target) >= 0;
        }

        pub fn index_of(self: ArrayList(T), target: T) isize {
            for (self.elements[0..self.size], 0..) |element, index| {
                if (checkEquality(element, target)) {
                    return @intCast(index);
                }
            }
            return -1;
        }

        pub fn isEmpty(self: ArrayList(T)) bool {
            return self.size == 0;
        }

        pub fn iterator(self: ArrayList(T)) Itr(T) {
            return Itr(T).init(self);
        }

        pub fn filter(self: ArrayList(T), predicate: fn (i32) bool) !Filter(T) {
            return Filter(T).init(self.allocator, self, predicate);
        }

        pub fn forEach(self: ArrayList(T), action: fn (i32) void) void {
            for (self.elements[0..self.size]) |element| {
                action(element);
            }
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

        fn checkEquality(one: T, other: T) bool {
            const type_info = @typeInfo(T);
            switch (type_info) {
                .Struct => return if (@hasDecl(T, "equals")) one.equals(other) else one == other,
                else => return one == other,
            }
        }

        pub fn Itr(comptime V: type) type {
            return struct {
                index: usize,
                size: usize,
                elements: []V,

                fn init(source: ArrayList(V)) Itr(V) {
                    return .{
                        .index = 0,
                        .size = source.size,
                        .elements = source.elements,
                    };
                }

                pub fn hasNext(self: Itr(V)) bool {
                    return self.index < self.size;
                }

                pub fn next(self: *Itr(V)) void {
                    self.index = self.index + 1;
                }

                pub fn element(self: Itr(V)) V {
                    return self.elements[self.index];
                }
            };
        }

        pub fn Filter(comptime V: type) type {
            return struct {
                filtered: std.ArrayList(V),
                allocator: std.mem.Allocator,

                fn init(allocator: std.mem.Allocator, source: ArrayList(V), predicate: fn (i32) bool) !Filter(V) {
                    var filtered = std.ArrayList(V).init(allocator);
                    for (source.elements[0..source.size]) |element| {
                        if (predicate(element)) {
                            try filtered.append(element);
                        }
                    }
                    return .{
                        .filtered = filtered,
                        .allocator = allocator,
                    };
                }

                pub fn allFiltered(self: Filter(V)) std.ArrayList(V) {
                    return self.filtered;
                }

                pub fn deinit(self: Filter(V)) void {
                    self.filtered.deinit();
                }
            };
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
    try std.testing.expectError(ArrayList(i32).Error.IndexOutOfBounds, list.get(1));
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

    try std.testing.expectError(ArrayList(i32).Error.NoSuchElement, list.getFirst());
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

    try std.testing.expectError(ArrayList(i32).Error.NoSuchElement, list.getLast());
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
    try std.testing.expectError(ArrayList(i32).Error.IndexOutOfBounds, list.set(1, 20));
}

test "matches an element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(20);
    try list.add(45);

    try std.testing.expect(list.matches_any(struct {
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

    try std.testing.expectEqual(false, list.matches_any(struct {
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

    try std.testing.expect(list.matches_all(struct {
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

    try std.testing.expectEqual(false, list.matches_all(struct {
        fn match(element: i32) bool {
            return @rem(element, 3) == 0;
        }
    }.match));
}

test "contains the element in the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    try std.testing.expect(list.contains(40));
}

test "does not contain the element in the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    try std.testing.expect(!list.contains(50));
}

test "finds the index of an element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    try std.testing.expectEqual(2, list.index_of(40));
}

test "does not find the index of an element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    try std.testing.expectEqual(-1, list.index_of(0));
}

test "iterates over an emty list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    var iterator = list.iterator();
    try std.testing.expect(!iterator.hasNext());
}

test "iterates over a non-emty list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    var iterator = list.iterator();
    try std.testing.expect(iterator.hasNext());

    try std.testing.expectEqual(15, iterator.element());

    iterator.next();
    try std.testing.expectEqual(21, iterator.element());

    iterator.next();
    try std.testing.expectEqual(40, iterator.element());

    iterator.next();
    try std.testing.expect(!iterator.hasNext());
}

test "filters elements in the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);

    const filter = try list.filter(struct {
        fn filter(element: i32) bool {
            return @rem(element, 2) == 0;
        }
    }.filter);
    defer filter.deinit();

    try std.testing.expectEqual(10, filter.allFiltered().items[0]);
    try std.testing.expectEqual(40, filter.allFiltered().items[1]);
}

test "deos not find any filtered elements in the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(11);
    try list.add(21);
    try list.add(41);

    const filter = try list.filter(struct {
        fn filter(element: i32) bool {
            return @rem(element, 2) == 0;
        }
    }.filter);
    defer filter.deinit();

    try std.testing.expectEqual(0, filter.allFiltered().items.len);
}

test "filters elements in the list ... " {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);

    const Sum = struct {
        var sumOfAll: i32 = 0;

        fn do(element: i32) void {
            sumOfAll = sumOfAll + element;
        }
    };

    list.forEach(Sum.do);

    try std.testing.expectEqual(71, Sum.sumOfAll);
}