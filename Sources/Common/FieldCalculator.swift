import Foundation

/// Port of the Android FieldCalculator: given a set of ship positions, computes
/// an NxN grid (N = Constants.numFields) where each cell holds either 9 (a ship) or a count from 0-3 of how
/// many ships cross that cell horizontally, vertically, or diagonally.
enum FieldCalculator {
    static func calculateFieldValues(_ ships: Set<Ship>) -> [[Int]] {
        var fields = Array(repeating: Array(repeating: 0, count: Constants.numFields), count: Constants.numFields)

        // Ships with an x/y outside the board are skipped rather than indexing
        // into `fields` with them: malformed server data (e.g. a ship placed by
        // a buggy client or test script with coordinates >= numFields) used to
        // crash this with an unrecoverable array-bounds trap — worse than the
        // equivalent Android crash, since Swift can't even catch it.
        for ship in ships where isInBounds(ship.x, ship.y) {
            fields[ship.x][ship.y] = 9
        }

        for ship in ships where isInBounds(ship.x, ship.y) {
            for y in 0..<Constants.numFields {
                setValue(ship.x, y, &fields)
            }
        }

        for ship in ships where isInBounds(ship.x, ship.y) {
            for x in 0..<Constants.numFields {
                setValue(x, ship.y, &fields)
            }
        }

        for ship in ships where isInBounds(ship.x, ship.y) {
            var x = ship.x
            var y = ship.y
            while x > 0 && y > 0 {
                x -= 1; y -= 1
                setValue(x, y, &fields)
            }
            x = ship.x; y = ship.y
            while x < Constants.numFields - 1 && y > 0 {
                x += 1; y -= 1
                setValue(x, y, &fields)
            }
            x = ship.x; y = ship.y
            while x > 0 && y < Constants.numFields - 1 {
                x -= 1; y += 1
                setValue(x, y, &fields)
            }
            x = ship.x; y = ship.y
            while x < Constants.numFields - 1 && y < Constants.numFields - 1 {
                x += 1; y += 1
                setValue(x, y, &fields)
            }
        }

        return fields
    }

    private static func isInBounds(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && x < Constants.numFields && y >= 0 && y < Constants.numFields
    }

    private static func setValue(_ x: Int, _ y: Int, _ fields: inout [[Int]]) {
        let value = fields[x][y]
        if value == 9 {
            // do nothing
        } else if value == 0 {
            fields[x][y] = 1
        } else if value < Constants.numShips {
            fields[x][y] = value + 1
        }
    }
}
