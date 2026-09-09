package chartdependency

import (
	"bytes"
	"errors"
	"fmt"

	"gopkg.in/yaml.v3"
)

var errDependencyNotFound = errors.New("dependency not found")

func DependencyVersion(data []byte, dependency string) (string, error) {
	root, err := parse(data)
	if err != nil {
		return "", err
	}

	item, err := findDependency(root, dependency)
	if err != nil {
		return "", err
	}
	version := mappingValue(item, "version")
	if version == nil || version.Value == "" {
		return "", fmt.Errorf("dependency %q has no version", dependency)
	}
	return version.Value, nil
}

func UpdateDependencyVersion(data []byte, dependency, version string) ([]byte, error) {
	root, err := parse(data)
	if err != nil {
		return nil, err
	}

	item, err := findDependency(root, dependency)
	if err != nil {
		return nil, err
	}
	versionNode := mappingValue(item, "version")
	if versionNode == nil {
		return nil, fmt.Errorf("dependency %q has no version", dependency)
	}
	versionNode.Value = version
	versionNode.Style = yaml.DoubleQuotedStyle
	return encode(root)
}

func TopLevelValue(data []byte, key string) (string, error) {
	root, err := parse(data)
	if err != nil {
		return "", err
	}
	value := mappingValue(root, key)
	if value == nil || value.Value == "" {
		return "", fmt.Errorf("top-level field %q has no value", key)
	}
	return value.Value, nil
}

func UpdateTopLevelValue(data []byte, key, value string) ([]byte, error) {
	root, err := parse(data)
	if err != nil {
		return nil, err
	}
	field := mappingValue(root, key)
	if field == nil {
		return nil, fmt.Errorf("top-level field %q not found", key)
	}
	field.Value = value
	field.Style = 0
	return encode(root)
}

func encode(root *yaml.Node) ([]byte, error) {

	var output bytes.Buffer
	encoder := yaml.NewEncoder(&output)
	encoder.SetIndent(2)
	if err := encoder.Encode(root); err != nil {
		return nil, err
	}
	if err := encoder.Close(); err != nil {
		return nil, err
	}
	return output.Bytes(), nil
}

func parse(data []byte) (*yaml.Node, error) {
	var root yaml.Node
	if err := yaml.Unmarshal(data, &root); err != nil {
		return nil, err
	}
	return &root, nil
}

func findDependency(root *yaml.Node, dependency string) (*yaml.Node, error) {
	dependencies := mappingValue(root, "dependencies")
	if dependencies == nil || dependencies.Kind != yaml.SequenceNode {
		return nil, fmt.Errorf("dependencies sequence not found")
	}
	for _, item := range dependencies.Content {
		if item.Kind == yaml.MappingNode {
			name := mappingValue(item, "name")
			if name != nil && name.Value == dependency {
				return item, nil
			}
		}
	}
	return nil, fmt.Errorf("%w: %s", errDependencyNotFound, dependency)
}

func mappingValue(mapping *yaml.Node, key string) *yaml.Node {
	if mapping == nil {
		return nil
	}
	if mapping.Kind == yaml.DocumentNode && len(mapping.Content) > 0 {
		mapping = mapping.Content[0]
	}
	if mapping.Kind != yaml.MappingNode {
		return nil
	}
	for index := 0; index+1 < len(mapping.Content); index += 2 {
		if mapping.Content[index].Value == key {
			return mapping.Content[index+1]
		}
	}
	return nil
}
