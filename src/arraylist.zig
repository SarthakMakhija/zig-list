const std = @import("std");

/// A contiguous, growable list of items in memory.
/// This is a wrapper around an array of T values. Initialize either with `initWithoutCapacity` or `initWithCapacity`.
///
/// This struct internally stores a `std.mem.Allocator` for memory management.
/// ArrayList is not concurrent-safe.
pub fn ArrayList(comptime T: type) type {
    return struct {
        elements: []T,
        index: usize,
        size: usize,
        allocator: std.mem.Allocator,

        /// A set of different errors that ArrayList can return.
        pub const Error = error{
            IndexOutOfBounds,
            NoSuchElement,
        };

        /// Default capacity of the internal backing array used by ArrayList.
        /// It is used when ArrayList is initialized using `initWithoutCapacity`.
        const DEFAULT_CAPACITY: usize = 10;

        /// Initialize ArrayList with `DEFAULT_CAPACITY`.
        pub fn initWithoutCapacity(allocator: std.mem.Allocator) !ArrayList(T) {
            return initWithCapacity(allocator, DEFAULT_CAPACITY);
        }

        /// Initialize ArrayList with the given capacity. It uses the allocator of type `std.mem.Allocator`
        /// to allocate the memory for the backing array.
        pub fn initWithCapacity(allocator: std.mem.Allocator, capacity: usize) !ArrayList(T) {
            return .{
                .elements = try allocator.alloc(T, capacity),
                .index = 0,
                .size = 0,
                .allocator = allocator,
            };
        }

        /// Add the element in the ArrayList. It performs an append operation.
        /// `add` operation can cause the underlying backing array to expand, if the backing array is full.
        pub fn add(self: *ArrayList(T), element: T) !void {
            if (self.index >= self.elements.len) {
                try self.grow(self.elements.len * 2);
            }
            self.elements[self.index] = element;
            self.index = self.index + 1;
            self.size = self.size + 1;
        }

        /// Add all the elements in the ArrayList. It performs an append operation with respect to the existing elements.
        /// `addAll` oepration can cause the underlying backing array to expand, if the backing array is full.
        pub fn addAll(self: *ArrayList(T), elements: []const T) !void {
            if (elements.len == 0) {
                return;
            }
            const remaining_capacity = self.elements.len - self.size;
            if (elements.len > remaining_capacity) {
                try self.grow(self.size + elements.len);
            }
            for (elements) |element| {
                self.elements[self.index] = element;
                self.index = self.index + 1;
                self.size = self.size + 1;
            }
        }

        /// Remove the element at the given index.
        /// `remove` returns an `IndexOutOfBounds` error if the index is beyond the bounds of the ArrayList.
        /// `remove` effectively shifts all elements after the removed index one position to the left.
        pub fn remove(self: *ArrayList(T), index: usize) !void {
            if (!isIndexInBounds(index, self.size)) {
                return Error.IndexOutOfBounds;
            }
            if (self.size - 1 > index) {
                var next_index: usize = index + 1;
                while (next_index < self.size) : (next_index += 1) {
                    self.elements[next_index - 1] = self.elements[next_index];
                }
            }
            self.index = self.index - 1;
            self.size = self.size - 1;
        }

        /// Remove the first element of the ArrayList, if the list is not empty.
        pub fn removeFirst(self: *ArrayList(T)) !void {
            if (self.isEmpty()) {
                return Error.NoSuchElement;
            }
            try self.remove(0);
        }

        /// Remove the last element of the ArrayList, if the list is not empty.
        pub fn removeLast(self: *ArrayList(T)) !void {
            if (self.isEmpty()) {
                return Error.NoSuchElement;
            }
            try self.remove(self.size - 1);
        }

        /// Set the element at the given index.
        /// `set` returns an `IndexOutOfBounds` error if the index is beyond the bounds of the ArrayList.
        pub fn set(self: ArrayList(T), index: usize, element: T) !void {
            if (!isIndexInBounds(index, self.size)) {
                return Error.IndexOutOfBounds;
            } else {
                self.elements[index] = element;
            }
        }

        /// Get the element at the given index.
        /// `get` returns an `IndexOutOfBounds` error if the index is beyond the bounds of the ArrayList.
        pub fn get(self: ArrayList(T), index: usize) !T {
            return if (!isIndexInBounds(index, self.size)) Error.IndexOutOfBounds else self.elements[index];
        }

        /// Get the first element of the ArrayList.
        /// getFirst returns a `NoSuchElement` error if the list is empty.
        pub fn getFirst(self: ArrayList(T)) !T {
            return if (self.isEmpty()) Error.NoSuchElement else self.elements[0];
        }

        /// Get the last element of the ArrayList.
        /// getLast returns a `NoSuchElement` error if the list is empty.
        pub fn getLast(self: ArrayList(T)) !T {
            return if (self.isEmpty()) Error.NoSuchElement else self.elements[self.size - 1];
        }

        /// Match any of the elements of the ArrayList using the given predicate.
        pub fn matches_any(self: ArrayList(T), predicate: fn (T) bool) bool {
            for (self.elements[0..self.size]) |element| {
                if (predicate(element)) {
                    return true;
                }
            }
            return false;
        }

        /// Match all the elements of the ArrayList using the given predicate.
        pub fn matches_all(self: ArrayList(T), predicate: fn (T) bool) bool {
            for (self.elements[0..self.size]) |element| {
                if (!predicate(element)) {
                    return false;
                }
            }
            return true;
        }

        /// Check if the target is contained in the ArrayList.
        /// `contains` returns true if the target is contained in the ArrayList, false otherwise.
        pub fn contains(self: ArrayList(T), target: T) bool {
            return self.indexOf(target) >= 0;
        }

        /// Return the index of the target in the ArrayList.
        /// `indexOf` returns -1 if the list does not contain the target.
        pub fn indexOf(self: ArrayList(T), target: T) isize {
            for (self.elements[0..self.size], 0..) |element, index| {
                if (checkEquality(element, target)) {
                    return @intCast(index);
                }
            }
            return -1;
        }

        /// Return true if the ArrayList is empty, false otherwise.
        pub fn isEmpty(self: ArrayList(T)) bool {
            return self.size == 0;
        }

        /// Return the size of the ArrayList.
        pub fn getSize(self: ArrayList(T)) usize {
            return self.size;
        }

        /// Return a forward moving iterator.
        pub fn iterator(self: ArrayList(T)) Itr(T) {
            return Itr(T).init(self);
        }

        /// Return a filter with all the values satisified by the given predicate.
        /// `filter` operation uses the allocator of the ArrayList to store all the filtered elements.
        ///  Filter provides support for releasing the allocation.
        pub fn filter(self: ArrayList(T), predicate: fn (i32) bool) !Filter(T) {
            return Filter(T).init(self.allocator, self, predicate);
        }

        /// Execute the given action over all the elements of the ArrayList.
        pub fn forEach(self: ArrayList(T), action: fn (i32) void) void {
            for (self.elements[0..self.size]) |element| {
                action(element);
            }
        }

        /// Release the memory allocated using the allocator of type std.mem.Allocator.
        pub fn deinit(self: ArrayList(T)) void {
            self.allocator.free(self.elements);
        }

        /// Grow the ArrayList to the new size.
        /// `grow` operation copies the existing elements to the newly allocated memory.
        /// It also frees the existing memory.
        fn grow(self: *ArrayList(T), new_size: usize) !void {
            const copied = try self.allocator.alloc(T, new_size);
            @memcpy(copied[0..self.elements.len], self.elements);
            self.allocator.free(self.elements);
            self.elements = copied;
        }

        /// Return true if index is within the exclusive bounds from 0 to bound_index.
        fn isIndexInBounds(index: usize, bound_index: usize) bool {
            return index >= 0 and index < bound_index;
        }

        /// Return true if the given values of type T are equal.
        /// It checks for the equality either using a custom `equals` method or the `==` operator.
        fn checkEquality(one: T, other: T) bool {
            const type_info = @typeInfo(T);
            switch (type_info) {
                .Struct => return if (@hasDecl(T, "equals")) one.equals(other) else one == other,
                else => return one == other,
            }
        }

        /// A forward moving iterator.
        /// It wraps the elements of ArrayList of type V. Initialize using the `init` method.
        pub fn Itr(comptime V: type) type {
            return struct {
                index: usize,
                size: usize,
                elements: []V,

                /// Initialize the Itr using the source of values.
                fn init(source: ArrayList(V)) Itr(V) {
                    return .{
                        .index = 0,
                        .size = source.size,
                        .elements = source.elements,
                    };
                }

                /// Return true if the iterator has the next element.
                pub fn hasNext(self: Itr(V)) bool {
                    return self.index < self.size;
                }

                /// Move the iterator to the next element.
                /// `hasNext` should be invoked before invoking `next`.
                pub fn next(self: *Itr(V)) void {
                    self.index = self.index + 1;
                }

                /// Return the element of type V at the current iterator position.
                pub fn element(self: Itr(V)) V {
                    return self.elements[self.index];
                }
            };
        }

        /// All the values of the source ArrayList which satisfy a predicate are represeted by a Filter type.
        /// It effectively contains all the values which satisfy a predicate.
        pub fn Filter(comptime V: type) type {
            return struct {
                filtered: std.ArrayList(V),
                allocator: std.mem.Allocator,

                /// Initialize the Filter.
                /// It uses the allocator of type `std.mem.Allocator` for allocating the collection to hold the filtered elements.
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

                /// Return all the filtered elements in form of `std.ArrayList`.
                pub fn allFiltered(self: Filter(V)) std.ArrayList(V) {
                    return self.filtered;
                }

                /// Release the memory allocated to hold the filtered elements.
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

test "adds an empty slice to the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    const empty = [_]i32{};

    try list.addAll(empty[0..]);
    try std.testing.expectEqual(0, list.getSize());
}

test "adds a slice to the list which does not require resize" {
    var list = try ArrayList(i32).initWithCapacity(std.testing.allocator, 5);
    defer list.deinit();

    const elements = [_]i32{ 10, 20, 30 };
    try list.addAll(elements[0..]);

    try std.testing.expectEqual(3, list.getSize());
    try std.testing.expect(list.contains(10));
    try std.testing.expect(list.contains(20));
    try std.testing.expect(list.contains(30));
}

test "adds a slice to the list which requires resize" {
    var list = try ArrayList(i32).initWithCapacity(std.testing.allocator, 5);
    defer list.deinit();

    try list.add(100);
    try list.add(200);

    const elements = [_]i32{ 10, 20, 30, 40 };

    try list.addAll(elements[0..]);

    try std.testing.expectEqual(6, list.getSize());
    try std.testing.expect(list.contains(10));
    try std.testing.expect(list.contains(20));
    try std.testing.expect(list.contains(30));
    try std.testing.expect(list.contains(100));
    try std.testing.expect(list.contains(200));
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

    try std.testing.expectEqual(2, list.indexOf(40));
}

test "does not find the index of an element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(15);
    try list.add(21);
    try list.add(40);

    try std.testing.expectEqual(-1, list.indexOf(0));
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

test "removes the first element from the list: I" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);

    try list.remove(0);

    try std.testing.expect(list.contains(21));
    try std.testing.expect(list.contains(40));
    try std.testing.expect(!list.contains(10));
}

test "removes the first element from the list: II" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);

    try list.removeFirst();

    try std.testing.expect(list.contains(21));
    try std.testing.expect(list.contains(40));
    try std.testing.expect(!list.contains(10));
}

test "removes one element from the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);
    try list.add(50);

    try list.remove(1);

    try std.testing.expect(list.contains(10));
    try std.testing.expect(list.contains(40));
    try std.testing.expect(list.contains(50));
    try std.testing.expect(!list.contains(21));
}

test "removes the last element from the list: I" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);

    try list.remove(2);

    try std.testing.expect(list.contains(10));
    try std.testing.expect(list.contains(21));
    try std.testing.expect(!list.contains(40));
}

test "removes the last element from the list: II" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);
    try list.add(21);
    try list.add(40);

    try list.removeLast();

    try std.testing.expect(list.contains(10));
    try std.testing.expect(list.contains(21));
    try std.testing.expect(!list.contains(40));
}

test "attempts to remove an element at an index which is beyond the bounds of the list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try list.add(10);

    try std.testing.expectError(ArrayList(i32).Error.IndexOutOfBounds, list.remove(2));
}

test "attempts to remove the first element from an empty list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectError(ArrayList(i32).Error.NoSuchElement, list.removeFirst());
}

test "attempts to remove the last element from an empty list" {
    var list = try ArrayList(i32).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectError(ArrayList(i32).Error.NoSuchElement, list.removeLast());
}

const User = struct {
    id: usize,
    name: []const u8,

    fn equals(self: User, other: User) bool {
        return self.id == other.id and std.mem.eql(u8, self.name, other.name);
    }
};

test "adds Users to the list" {
    var list = try ArrayList(User).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    const users = [_]User{
        .{ .id = 10, .name = "John" },
        .{ .id = 20, .name = "Rahul" },
        .{ .id = 30, .name = "Mark" },
    };

    try list.addAll(users[0..]);

    try std.testing.expect(list.contains(User{ .id = 10, .name = "John" }));
    try std.testing.expect(list.contains(User{ .id = 20, .name = "Rahul" }));
    try std.testing.expect(list.contains(User{ .id = 30, .name = "Mark" }));
}

test "adds and gets Users to/from the list" {
    var list = try ArrayList(User).initWithoutCapacity(std.testing.allocator);
    defer list.deinit();

    const users = [_]User{
        .{ .id = 10, .name = "John" },
        .{ .id = 20, .name = "Rahul" },
        .{ .id = 30, .name = "Mark" },
    };

    try list.addAll(users[0..]);

    try std.testing.expectEqual(User{ .id = 10, .name = "John" }, list.getFirst());
    try std.testing.expectEqual(User{ .id = 20, .name = "Rahul" }, list.get(1));
    try std.testing.expectEqual(User{ .id = 30, .name = "Mark" }, list.getLast());
}

test "iterates over a list of Users" {
    var list = try ArrayList(User).initWithCapacity(std.testing.allocator, 2);
    defer list.deinit();

    const users = [_]User{
        .{ .id = 10, .name = "John" },
        .{ .id = 20, .name = "Rahul" },
        .{ .id = 30, .name = "Mark" },
        .{ .id = 40, .name = "Carol" },
    };

    try list.addAll(users[0..]);

    var iterator = list.iterator();
    try std.testing.expectEqual(User{ .id = 10, .name = "John" }, iterator.element());

    iterator.next();
    try std.testing.expectEqual(User{ .id = 20, .name = "Rahul" }, iterator.element());

    iterator.next();
    try std.testing.expectEqual(User{ .id = 30, .name = "Mark" }, iterator.element());

    iterator.next();
    try std.testing.expectEqual(User{ .id = 40, .name = "Carol" }, iterator.element());

    iterator.next();
    try std.testing.expect(!iterator.hasNext());
}
