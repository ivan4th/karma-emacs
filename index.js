// TBD: onBrowserError (message)
// TBD: don't output browser type unless there are more than one browser
var os = require("os"),
    path = require("path"),
    fs = require("fs"),
    http = require("http");

var EmacsReporter = function(baseReporterDecorator, config, logger, helper, formatError) {
  var lgr = logger.create('reporter.emacs'); // TBD: rename var ('log' conflicts with 'log' below)

  baseReporterDecorator(this);

  var updatePending = false,
      postInProgress = false,
      postDone = null,
      pendingLogs = [],
      running = false,
      total = 0,
      nSuccess = 0,
      nSkipped = 0,
      nFailed = 0;

  function postStatus (log, auto) {
    if (log)
      pendingLogs.push(log);

    if ((!auto && postInProgress) ||
        (auto && !updatePending)) {
      updatePending = true;
      return;
    }

    updatePending = false;
    postInProgress = true;

    var data = {
      logs: pendingLogs.slice(),
      status: {
        running: running,
        total: total,
        success: nSuccess,
        skipped: nSkipped,
        failed: nFailed
      }
    };
    pendingLogs.length = 0; // FIXME: make sure the request succeeds

    var responseText = [],
        body = JSON.stringify(data);

    console.log("POST: " + body);
    var req = http.request({
      hostname: "localhost",
      port: 8008, // TBD: config
      path: "/karma/post",
      method: 'POST',
      headers: {
        "Content-Length": body.length, //Buffer.byteLength(body, "utf8"),
        "Content-Type": "application/json"
      }
    }, function(res) {
      // console.log('STATUS: ' + res.statusCode);
      // console.log('HEADERS: ' + JSON.stringify(res.headers));
      res.setEncoding("utf8");
      res.on("data", function (chunk) {
        responseText.push(chunk);
      });
      res.on("end", function () {
        console.log("server response: " + responseText.join(""));
        postInProgress = false;
        if (postDone) {
          postDone();
          postDone = null;
        }
        if (updatePending) {
          postStatus(null, true);
        }
      });
    }).on("error", function(e) {
      lgr.warn("HTTP error: " + e.message);
      postInProgress = false;
      if (postDone) {
        postDone();
        postDone = null;
      }
    });

    req.write(body);
    req.end();
  }

  this.adapters = [function(msg) {
    // allMessages.push(msg);
  }];

  this.onRunStart = function (browsers) {
    running = true;
    total = nSuccess = nSkipped = nFailed = 0;
    // console.log("onRunStart " + JSON.stringify(Object.keys(browsers)));
    // try{throw new Error("qqq");} catch (e) {
    //   console.log(e.stack);
    // }
    postStatus();
  };

  this.onBrowserStart = function(browser) {
    total += browser.lastResult.total;
    postStatus();
  };

  this.onBrowserComplete = function(browser) {
  };

  this.onBrowserLog = function (browser, log, type) {
    if (typeof(log) != "string") {
      try {
        log = "" + log;
      } catch (e) {
        log = "<cannot convert value to string>";
      }
    }
    console.log("onBrowserLog: " + JSON.stringify([
      "" + browser,
      type.toUpperCase(),
      log
    ]));
    postStatus([
      "" + browser,
      type.toUpperCase(),
      log
    ]);
  };

  this.onRunComplete = function() {
    running = false;
    postStatus();
    // allMessages.length = 0;
  };

  this.specSuccess = function (browser, result) {
    ++nSuccess;
    postStatus();
  };

  this.specSkipped = function (browser, result) {
    ++nSkipped;
    postStatus();
  };

  this.specFailure = function (browser, result) {
    var specName = result.suite.join(" ") + " " + result.description;
    var msg = browser + " " + specName + " FAILED\n";

    result.log.forEach(function(log) {
      msg += formatError(log, "        ");
    });

    postStatus(["" + browser, "TESTFAIL", msg]);

    ++nFailed;
    postStatus();
  };

  this.onExit = function(done) {
    if (postInProgress)
      postDone = done;
    else
      done();
  };
};

EmacsReporter.$inject = ["baseReporterDecorator", "config", "logger", "helper", "formatError"];

module.exports = {
  "reporter:emacs": ["type", EmacsReporter]
};
