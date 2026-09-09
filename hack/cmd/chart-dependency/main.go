package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/densify-dev/helm-charts/hack/internal/chartdependency"
)

func main() {
	file := flag.String("file", "", "Chart.yaml path")
	dependency := flag.String("dependency", "", "dependency name")
	version := flag.String("version", "", "new dependency version; omit to read the current version")
	topLevelKey := flag.String("top-level-key", "", "top-level chart field to read or update")
	topLevelValue := flag.String("top-level-value", "", "new top-level field value; omit to read the current value")
	flag.Parse()

	if *file == "" || (*dependency == "" && *topLevelKey == "") || (*dependency != "" && *topLevelKey != "") {
		fatal("-file and exactly one of -dependency or -top-level-key are required")
	}

	data, err := os.ReadFile(*file)
	if err != nil {
		fatal("read %s: %v", *file, err)
	}

	if *topLevelKey != "" {
		if *topLevelValue == "" {
			current, err := chartdependency.TopLevelValue(data, *topLevelKey)
			if err != nil {
				fatal("read top-level field: %v", err)
			}
			fmt.Println(current)
			return
		}
		updated, err := chartdependency.UpdateTopLevelValue(data, *topLevelKey, *topLevelValue)
		if err != nil {
			fatal("update top-level field: %v", err)
		}
		if err := os.WriteFile(*file, updated, 0o644); err != nil {
			fatal("write %s: %v", *file, err)
		}
		return
	}

	if *version == "" {
		current, err := chartdependency.DependencyVersion(data, *dependency)
		if err != nil {
			fatal("read dependency: %v", err)
		}
		fmt.Println(current)
		return
	}

	updated, err := chartdependency.UpdateDependencyVersion(data, *dependency, *version)
	if err != nil {
		fatal("update dependency: %v", err)
	}
	if err := os.WriteFile(*file, updated, 0o644); err != nil {
		fatal("write %s: %v", *file, err)
	}
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}
