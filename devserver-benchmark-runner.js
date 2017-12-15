const {spawn} = require('child_process');
const fs = require('fs');
const puppeteer = require('puppeteer');
const tempy = require('tempy');

function runBenchmark() {
  const args = process.argv.slice(2);
  if (args.length < 3 || args.length > 5) {
    usage();
    process.exit(1);
  }

  const profileFilename = tempy.file({extension: 'json'});
  const runTarget = args[0];
  const fileToTouch = args[1];
  const browserUrl = args[2];
  const initialTimeout = parseInt(args[3]) || 300;
  const incrementalTimeout = parseInt(args[4]) || 10;
  let done = false;

  console.log('Starting benchmark');
  console.log(`  Devserver run target: ${runTarget}`);
  console.log(`  File to touch: ${fileToTouch}`);
  console.log(`  Browser url: ${browserUrl}`);
  console.log(`  Initial timeout: ${initialTimeout}s`);
  console.log(`  Incremental timeout: ${incrementalTimeout}s`);

  console.log('Starting iBazel');
  const child =
      spawn('node_modules/.bin/ibazel', [`-profile_dev=${profileFilename}`, 'run', runTarget]);

  // Pipe iBazel output to console
  child.stdout.pipe(process.stdout);
  child.stderr.pipe(process.stderr);

  function shutdown() {
    done = true;
    child.kill('SIGTERM');
    setTimeout(() => {
      console.error("iBazel did not shutdown");
      process.exit(1);
    }, 5000);
  }

  function onShutdown(code, signal) {
    if (!done) {
      console.error(`iBazel process exited unexpectedly ${code} ${signal}`);
      process.exit(1);
    } else {
      process.exit()
    }
  }

  child.on('close', onShutdown);
  child.on('exit', onShutdown);

  // Give the initial build 5 minutes
  waitForProfilerEvent(profileFilename, 'RUN_DONE', null, initialTimeout * 1000)
      .then((event) => {
        console.log('Launching chrome');
        return puppeteer.launch()
            .then((browser) => browser.newPage())
            .then((page) => page.goto(browserUrl))
            // Wait for browser to open page
            .then(() => waitForProfilerEvent(profileFilename, 'REMOTE_EVENT', null, incrementalTimeout * 1000))
            // Touch a file to start an incremental build
            .then(() => touchFile(fileToTouch))
            // Give the incremental build 10 seconds
            .then(
                () => waitForProfilerEvent(
                    profileFilename, 'REMOTE_EVENT', event.iteration, 10 * 1000))
      })
      .then((event) => {
        console.log(`RTT ${event.elapsed}ms`);
        shutdown();
      })
      .catch((err) => {
        console.error('Benchmark failed', err);
        shutdown();
      });
}

function touchFile(filename) {
  console.log(`Touching file ${filename}`);
  fs.appendFileSync(filename, '\n');
}

function waitForProfilerEvent(filename, eventType, ignoreIteration, timeout) {
  console.log(`Waiting for ${eventType} event...`);
  const start = Date.now();
  return new Promise((fulfill, reject) => {
    const interval = setInterval(() => {
      if (fs.existsSync(filename)) {
        const data = fs.readFileSync(filename).toString();
        const lastLine = compact(data.split('\n')).pop();
        if (lastLine) {
          try {
            const event = JSON.parse(lastLine);
            if (event.type === eventType) {
              if (!ignoreIteration || ignoreIteration !== event.iteration) {
                console.log(`Found ${eventType}`);
                clearInterval(interval);
                fulfill(event);
              }
            }
          } catch (e) {
            console.error('Failed to parse profile output');
          }
        }
      }
      const elapsed = Date.now() - start;
      if (elapsed > timeout) {
        reject('Timeout exceeed');
      }
    }, 250);
  })
}

function usage() {
  console.log(`Usage: node benchmark.js <devserver run target> <file to touch> <browser url> [initial build timeout seconds] [incremental build timeout seconds]`)
}

function compact(a) {
  return a.filter((e) => e !== (undefined || null || ''));
}

runBenchmark();
