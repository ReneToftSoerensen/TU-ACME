//# hash=73eb42692c40e42b8c97c93b154ee230
//# sourceMappingURL=menu.test.js.map

function asyncGeneratorStep(gen, resolve, reject, _next, _throw, key, arg) {
    try {
        var info = gen[key](arg);
        var value = info.value;
    } catch (error) {
        reject(error);
        return;
    }
    if (info.done) {
        resolve(value);
    } else {
        Promise.resolve(value).then(_next, _throw);
    }
}
function _async_to_generator(fn) {
    return function() {
        var self = this, args = arguments;
        return new Promise(function(resolve, reject) {
            var gen = fn.apply(self, args);
            function _next(value) {
                asyncGeneratorStep(gen, resolve, reject, _next, _throw, "next", value);
            }
            function _throw(err) {
                asyncGeneratorStep(gen, resolve, reject, _next, _throw, "throw", err);
            }
            _next(undefined);
        });
    };
}
function _ts_generator(thisArg, body) {
    var f, y, t, _ = {
        label: 0,
        sent: function() {
            if (t[0] & 1) throw t[1];
            return t[1];
        },
        trys: [],
        ops: []
    }, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype), d = Object.defineProperty;
    return d(g, "next", {
        value: verb(0)
    }), d(g, "throw", {
        value: verb(1)
    }), d(g, "return", {
        value: verb(2)
    }), typeof Symbol === "function" && d(g, Symbol.iterator, {
        value: function() {
            return this;
        }
    }), g;
    function verb(n) {
        return function(v) {
            return step([
                n,
                v
            ]);
        };
    }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while(g && (g = 0, op[0] && (_ = 0)), _)try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [
                op[0] & 2,
                t.value
            ];
            switch(op[0]){
                case 0:
                case 1:
                    t = op;
                    break;
                case 4:
                    _.label++;
                    return {
                        value: op[1],
                        done: false
                    };
                case 5:
                    _.label++;
                    y = op[1];
                    op = [
                        0
                    ];
                    continue;
                case 7:
                    op = _.ops.pop();
                    _.trys.pop();
                    continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) {
                        _ = 0;
                        continue;
                    }
                    if (op[0] === 3 && (!t || op[1] > t[0] && op[1] < t[3])) {
                        _.label = op[1];
                        break;
                    }
                    if (op[0] === 6 && _.label < t[1]) {
                        _.label = t[1];
                        t = op;
                        break;
                    }
                    if (t && _.label < t[2]) {
                        _.label = t[2];
                        _.ops.push(op);
                        break;
                    }
                    if (t[2]) _.ops.pop();
                    _.trys.pop();
                    continue;
            }
            op = body.call(thisArg, _);
        } catch (e) {
            op = [
                6,
                e
            ];
            y = 0;
        } finally{
            f = t = 0;
        }
        if (op[0] & 5) throw op[1];
        return {
            value: op[0] ? op[1] : void 0,
            done: true
        };
    }
}
// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
//
// End-to-end tests that drive the TU-ACME interactive menu (Start-TUACME)
// through a real pwsh terminal. Assertions stay at the menu / navigation layer
// (rendering, valid/invalid keys, quitting) so nothing IIS- or Posh-ACME-bound
// is exercised; deeper logic stays covered by the Pester unit/integration suites.
import { test, expect } from "@microsoft/tui-test";
test("renders the banner and the main menu", function(param) {
    var terminal = param.terminal;
    return _async_to_generator(function() {
        return _ts_generator(this, function(_state) {
            switch(_state.label){
                case 0:
                    return [
                        4,
                        expect(terminal.getByText("TU-ACME")).toBeVisible()
                    ];
                case 1:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("A Text User Interface for Posh-ACME on Windows (PowerShell 7)")).toBeVisible()
                    ];
                case 2:
                    _state.sent();
                    // Every main-menu entry is present.
                    return [
                        4,
                        expect(terminal.getByText("N: Create certificate (full options)")).toBeVisible()
                    ];
                case 3:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("M: Manage renewals", {
                            strict: false
                        })).toBeVisible()
                    ];
                case 4:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("B: Browse IIS bindings")).toBeVisible()
                    ];
                case 5:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("S: Manage ACME accounts")).toBeVisible()
                    ];
                case 6:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("T: Manage scheduled renewal tasks")).toBeVisible()
                    ];
                case 7:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("Q: Quit")).toBeVisible()
                    ];
                case 8:
                    _state.sent();
                    return [
                        2
                    ];
            }
        });
    })();
});
test("rejects an invalid menu key with a warning", function(param) {
    var terminal = param.terminal;
    return _async_to_generator(function() {
        return _ts_generator(this, function(_state) {
            switch(_state.label){
                case 0:
                    return [
                        4,
                        expect(terminal.getByText("Q: Quit")).toBeVisible()
                    ];
                case 1:
                    _state.sent();
                    // 'X' is not one of N, M, B, S, T, Q -> Read-MenuChoice warns and re-prompts.
                    terminal.submit("X");
                    return [
                        4,
                        expect(terminal.getByText("Invalid choice. Valid: N, M, B, S, T, Q", {
                            strict: false
                        })).toBeVisible()
                    ];
                case 2:
                    _state.sent();
                    // The menu is shown again after the rejected key.
                    return [
                        4,
                        expect(terminal.getByText("Q: Quit")).toBeVisible()
                    ];
                case 3:
                    _state.sent();
                    return [
                        2
                    ];
            }
        });
    })();
});
test("quits cleanly on Q", function(param) {
    var terminal = param.terminal;
    return _async_to_generator(function() {
        return _ts_generator(this, function(_state) {
            switch(_state.label){
                case 0:
                    return [
                        4,
                        expect(terminal.getByText("Q: Quit")).toBeVisible()
                    ];
                case 1:
                    _state.sent();
                    terminal.submit("Q");
                    return [
                        4,
                        expect(terminal.getByText("Goodbye.")).toBeVisible()
                    ];
                case 2:
                    _state.sent();
                    return [
                        2
                    ];
            }
        });
    })();
});
