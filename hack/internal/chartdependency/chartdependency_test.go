package chartdependency

import "testing"

func TestDependencyVersionSupportsKeyOrderAndQuotedNames(t *testing.T) {
	data := []byte(`apiVersion: v2
dependencies:
  - repository: https://example.invalid
    name: "kubex-automation-engine"
    condition: enabled
    version: "1.10.1"
`)

	version, err := DependencyVersion(data, "kubex-automation-engine")
	if err != nil {
		t.Fatalf("DependencyVersion() error = %v", err)
	}
	if version != "1.10.1" {
		t.Fatalf("DependencyVersion() = %q, want %q", version, "1.10.1")
	}
}

func TestUpdateDependencyVersionScopesToMatchingItem(t *testing.T) {
	data := []byte(`dependencies:
  - name: other
    version: "1.0.0"
  - repository: https://example.invalid
    condition: enabled
    name: kubex-automation-engine
    version: "1.10.1"
  - name: final
    version: "3.0.0"
`)

	updated, err := UpdateDependencyVersion(data, "kubex-automation-engine", "1.11.0")
	if err != nil {
		t.Fatalf("UpdateDependencyVersion() error = %v", err)
	}

	if got, err := DependencyVersion(updated, "kubex-automation-engine"); err != nil || got != "1.11.0" {
		t.Fatalf("updated dependency version = %q, error = %v", got, err)
	}
	if got, err := DependencyVersion(updated, "other"); err != nil || got != "1.0.0" {
		t.Fatalf("other dependency version = %q, error = %v", got, err)
	}
}

func TestDependencyVersionMissingDependency(t *testing.T) {
	_, err := DependencyVersion([]byte("dependencies: []\n"), "kubex-automation-engine")
	if err == nil {
		t.Fatal("DependencyVersion() error = nil, want an error")
	}
}

func TestUpdateTopLevelValueDoesNotChangeDependencyVersions(t *testing.T) {
	data := []byte(`version: 1.1.1
dependencies:
  - name: kubex-automation-engine
    version: "1.10.1"
`)

	updated, err := UpdateTopLevelValue(data, "version", "1.1.2")
	if err != nil {
		t.Fatalf("UpdateTopLevelValue() error = %v", err)
	}
	if got, err := TopLevelValue(updated, "version"); err != nil || got != "1.1.2" {
		t.Fatalf("top-level version = %q, error = %v", got, err)
	}
	if got, err := DependencyVersion(updated, "kubex-automation-engine"); err != nil || got != "1.10.1" {
		t.Fatalf("dependency version = %q, error = %v", got, err)
	}
}
