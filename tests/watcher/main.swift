// watcher-test.swift — developer test for FileWatcher: in-place write, atomic save (temp + rename), delete, reappear.
// Run via tests/watcher/run.sh. Prints PASS/FAIL per scenario.
import Foundation

let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wt-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let file = dir.appendingPathComponent("a.md")
try! "one".write(to: file, atomically: false, encoding: .utf8)

var changes = 0, missings = 0
let watcher = FileWatcher(url: file, onChange: { changes += 1 }, onMissing: { missings += 1 })
var failed = false

func wait(_ s: Double) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }
func check(_ name: String, _ ok: Bool) { print(ok ? "PASS" : "FAIL", name); if !ok { failed = true } }

wait(0.3)
try! "two!".write(to: file, atomically: false, encoding: .utf8)          // editor writing in place
wait(0.6); check("in-place write", changes == 1)

try! "three!!".write(to: file, atomically: true, encoding: .utf8)        // atomic save: temp file + rename
wait(0.6); check("atomic save", changes == 2)
try! "four!!!!".write(to: file, atomically: true, encoding: .utf8)       // second atomic save (watch must have re-armed)
wait(0.6); check("second atomic save", changes == 3)

try! FileManager.default.removeItem(at: file)
wait(0.6); check("delete -> missing", missings == 1)

try! "back".write(to: file, atomically: true, encoding: .utf8)
wait(1.5); check("reappear -> change", changes == 4)
try! "edited again".write(to: file, atomically: false, encoding: .utf8)
wait(0.6); check("write after reappear", changes == 5)

watcher.stop()
exit(failed ? 1 : 0)
