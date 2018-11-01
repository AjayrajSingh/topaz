// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// process_startup_trace.go
//
// Usage:
//
// /pkgfs/packages/scenic_benchmarks/0/bin/process_startup_trace      \
//    [-test_suite_name=label] [-benchmarks_out_filename=output_file] \
//    -flutter_app_name=app_name trace_filename
//
// label = Optional: The name of the test suite.
// output_file = Optional: A file to output results to.
// app_name = The name of the flutter app to measure fps for.
// trace_filename = The input trace files.
//
// The output is a JSON file with benchmark statistics.

package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"fuchsia.googlesource.com/benchmarking"
)

const OneMsecInUsecs float64 = 1000

var (
	verbose = false
)

func check(e error) {
	if e != nil {
		panic(e)
	}
}

func getThreadsWithName(model benchmarking.Model, name string) []benchmarking.Thread {
	threads := make([]benchmarking.Thread, 0)
	for _, process := range model.Processes {
		for _, thread := range process.Threads {
			if thread.Name == name {
				threads = append(threads, thread)
			}
		}
	}
	return threads
}

func reportEvent(event benchmarking.Event, label string, testSuite string, testResultsFile *benchmarking.TestResultsFile) {
	dur := event.Dur / OneMsecInUsecs
	fmt.Printf("%-35s: %.4gms\n", label, dur)
	testResultsFile.Add(&benchmarking.TestCaseResults{
		Label:     label,
		TestSuite: testSuite,
		Unit:      benchmarking.Unit(benchmarking.Milliseconds),
		Values:    []float64{dur},
	})
}

func reportEventsTotal(events []benchmarking.Event, label string, testSuite string, testResultsFile *benchmarking.TestResultsFile) {
	label = "Total time in " + label
	total := benchmarking.AvgDuration(events) * float64(len(events)) / OneMsecInUsecs
	fmt.Printf("%-35s: %.4gms\n", label, total)
	testResultsFile.Add(&benchmarking.TestCaseResults{
		Label:     label,
		TestSuite: testSuite,
		Unit:      benchmarking.Unit(benchmarking.Milliseconds),
		Values:    []float64{total},
	})
}

func reportStartupMetrics(model benchmarking.Model, appName string, testSuite string, testResultsFile *benchmarking.TestResultsFile) {
	fmt.Printf("=== Startup Metrics ===\n")
	createStoryCallStr := "SessionStorage::CreateStoryCall"
	createStoryCallEvent := model.FindEvents(benchmarking.EventsFilter{Name: &createStoryCallStr})[0]
	storyStartTime := createStoryCallEvent.Start
	addModStr := "StoryCommand::AddMod"
	addModEvent := model.FindEvents(benchmarking.EventsFilter{Name: &addModStr})[0]

	flutterUIThread := getThreadsWithName(model, appName+".ui")[0]

	createRootIsolateStr := "DartIsolate::CreateRootIsolate"
	createRootIsolateEvent := flutterUIThread.FindEvents(benchmarking.EventsFilter{Name: &createRootIsolateStr})[0]
	serviceIsolateStartupStr := "ServiceIsolateStartup"
	serviceIsolateStartupEvents := model.FindEvents(benchmarking.EventsFilter{Pid: &createRootIsolateEvent.Pid, Name: &serviceIsolateStartupStr})
	// This event is only emitted if flutter profiling is enabled.
	var serviceIsolateStartupEvent benchmarking.Event
	if len(serviceIsolateStartupEvents) > 0 {
		serviceIsolateStartupEvent = serviceIsolateStartupEvents[0]
	}

	flutterGPUThread := getThreadsWithName(model, appName+".gpu")[0]
	sessionPresentStr := "SessionPresent"
	firstSessionPresentEvent := flutterGPUThread.FindEvents(benchmarking.EventsFilter{Name: &sessionPresentStr})[0]

	startupEndTime := firstSessionPresentEvent.Start + firstSessionPresentEvent.Dur
	totalDuration := startupEndTime - storyStartTime

	ledgerStr := "ledger"
	ledgerGetPageStr := "ledger_get_page"
	ledgerGetPageEvents := model.FindEvents(benchmarking.EventsFilter{Cat: &ledgerStr, Name: &ledgerGetPageStr})
	ledgerBatchUploadStr := "batch_upload"
	ledgerBatchUploadEvents := model.FindEvents(benchmarking.EventsFilter{Cat: &ledgerStr, Name: &ledgerBatchUploadStr})
	ledgerEvents := append(ledgerGetPageEvents, ledgerBatchUploadEvents...)

	fileGetVmoStr := "FileGetVmo"
	fileGetVmoEvents := model.FindEvents(benchmarking.EventsFilter{Name: &fileGetVmoStr})

	reportEvent(createStoryCallEvent, "CreateStoryCall", testSuite, testResultsFile)
	reportEvent(addModEvent, "AddMod", testSuite, testResultsFile)
	if serviceIsolateStartupEvent.Name != "" {
		reportEvent(serviceIsolateStartupEvent, "ServiceIsolateStartup", testSuite, testResultsFile)
	}
	reportEvent(createRootIsolateEvent, "CreateRootIsolate", testSuite, testResultsFile)
	reportEventsTotal(ledgerEvents, "Ledger", testSuite, testResultsFile)
	reportEventsTotal(fileGetVmoEvents, "FileGetVmo", testSuite, testResultsFile)

	total := totalDuration / OneMsecInUsecs
	fmt.Printf("%-35s: %.4gms\n", "Total Startup Time", total)
	testResultsFile.Add(&benchmarking.TestCaseResults{
		Label:     "Total",
		TestSuite: testSuite,
		Unit:      benchmarking.Unit(benchmarking.Milliseconds),
		Values:    []float64{total},
	})
}

func main() {
	// Argument handling.
	verbosePtr := flag.Bool("v", false, "Run with verbose logging")
	flutterAppNamePtr := flag.String("flutter_app_name", "", "The name of the flutter app to measure fps for.")
	testSuitePtr := flag.String("test_suite_name", "", "Optional: The name of the test suite.")
	outputFilenamePtr := flag.String("benchmarks_out_filename", "", "Optional: A file to output results to.")

	flag.Parse()
	if flag.NArg() == 0 || *flutterAppNamePtr == "" {
		flag.Usage()
		println("  trace_filename: The input trace file.")
		os.Exit(1)
	}

	verbose = *verbosePtr
	inputFilename := flag.Args()[0]
	flutterAppName := *flutterAppNamePtr
	testSuite := *testSuitePtr
	outputFilename := *outputFilenamePtr

	traceFile, err := ioutil.ReadFile(inputFilename)
	check(err)

	// Creating the trace model.
	var model benchmarking.Model
	model, err = benchmarking.ReadTrace(traceFile)
	check(err)

	if len(model.Processes) == 0 {
		panic("No processes found in the model")
	}

	var testResultsFile benchmarking.TestResultsFile
	reportStartupMetrics(model, flutterAppName, testSuite, &testResultsFile)

	if outputFilename != "" {
		outputFile, err := os.Create(outputFilename)
		if err != nil {
			log.Fatalf("failed to create file %s", outputFilename)
		}

		if err := testResultsFile.Encode(outputFile); err != nil {
			log.Fatalf("failed to write results to %s: %v", outputFilename, err)
		}

		fmt.Printf("\n\nWrote benchmark values to file '%s'.\n", outputFilename)
	}
}
