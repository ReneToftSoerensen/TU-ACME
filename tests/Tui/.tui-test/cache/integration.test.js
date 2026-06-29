//# hash=be19c4be6e7d587a698671f182a66622
//# sourceMappingURL=integration.test.js.map

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
// Full-scale integration test: drive the N wizard end-to-end so the TUI issues
// a REAL certificate against the test ACME server (Pebble), using the IIS site
// with an HTTP host-header binding that CI provisions and the DNS test plugin
// (ChallTestSrv) configured by launch.ps1.
//
// This is the Windows-only counterpart of tests/Integration/*.Integration.Tests.ps1
// but exercised through the interactive UI rather than the helpers directly. It
// is opt-in: it only runs when CI has provisioned the ACME server + IIS host
// header (signalled by TUACME_TUI_INTEGRATION=1). Off that path it is skipped,
// so a plain `npx @microsoft/tui-test` run executes only the menu specs.
import { test, expect } from "@microsoft/tui-test";
var integrationEnabled = process.env.TUACME_TUI_INTEGRATION === "1" && !!process.env.TUACME_ACME_DIRECTORY && !!process.env.TUACME_TUI_HOST;
// Allow plenty of time for the ACME order -> DNS-01 -> finalize round trip.
var issueTimeout = 4 * 60 * 1000;
test.when(integrationEnabled, "issues a certificate end-to-end through the wizard", function(param) {
    var terminal = param.terminal;
    return _async_to_generator(function() {
        return _ts_generator(this, function(_state) {
            switch(_state.label){
                case 0:
                    // Main menu -> N: Create certificate.
                    return [
                        4,
                        expect(terminal.getByText("Q: Quit")).toBeVisible()
                    ];
                case 1:
                    _state.sent();
                    terminal.submit("N");
                    // Step 1: Select IIS Sites -> select all, then confirm.
                    return [
                        4,
                        expect(terminal.getByText("Step 1: Select IIS Sites")).toBeVisible()
                    ];
                case 2:
                    _state.sent();
                    terminal.submit("s s");
                    return [
                        4,
                        expect(terminal.getByText("Step 1: Select IIS Sites")).toBeVisible()
                    ];
                case 3:
                    _state.sent();
                    terminal.submit("c");
                    // Step 2: Filter Host Headers -> confirm the (single host-header) selection.
                    return [
                        4,
                        expect(terminal.getByText("Step 2: Filter Host Headers")).toBeVisible()
                    ];
                case 4:
                    _state.sent();
                    terminal.submit("c");
                    // Step 3: Choose Common Name -> Enter accepts the default (first host),
                    // then confirm the identifier list.
                    return [
                        4,
                        expect(terminal.getByText("Step 3: Choose Common Name")).toBeVisible()
                    ];
                case 5:
                    _state.sent();
                    terminal.submit("");
                    return [
                        4,
                        expect(terminal.getByText("Confirm? (y/r/x)")).toBeVisible()
                    ];
                case 6:
                    _state.sent();
                    terminal.submit("y");
                    // Step 4: ACME options -> confirm and request (plugin comes from config).
                    return [
                        4,
                        expect(terminal.getByText("Step 4: ACME options")).toBeVisible()
                    ];
                case 7:
                    _state.sent();
                    terminal.submit("c");
                    // Step 5: Confirm & run.
                    return [
                        4,
                        expect(terminal.getByText("Step 5: Confirm & run")).toBeVisible()
                    ];
                case 8:
                    _state.sent();
                    return [
                        4,
                        expect(terminal.getByText("Proceed?")).toBeVisible()
                    ];
                case 9:
                    _state.sent();
                    terminal.submit("y");
                    // The real issuance happens here; wait for the success line.
                    return [
                        4,
                        expect(terminal.getByText("Certificate issued. Thumbprint:")).toBeVisible({
                            timeout: issueTimeout
                        })
                    ];
                case 10:
                    _state.sent();
                    // Step 6 offers to create an HTTPS binding for the HTTP-only host; decline
                    // to keep the assertion focused on issuance, then continue past Wait-UI.
                    return [
                        4,
                        expect(terminal.getByText("Create a new HTTPS binding", {
                            strict: false
                        })).toBeVisible()
                    ];
                case 11:
                    _state.sent();
                    terminal.submit("n");
                    return [
                        4,
                        expect(terminal.getByText("Press Enter to continue", {
                            strict: false
                        })).toBeVisible()
                    ];
                case 12:
                    _state.sent();
                    terminal.submit("");
                    // Back at the main menu -> quit cleanly.
                    return [
                        4,
                        expect(terminal.getByText("Q: Quit")).toBeVisible()
                    ];
                case 13:
                    _state.sent();
                    terminal.submit("Q");
                    return [
                        4,
                        expect(terminal.getByText("Goodbye.")).toBeVisible()
                    ];
                case 14:
                    _state.sent();
                    return [
                        2
                    ];
            }
        });
    })();
});
