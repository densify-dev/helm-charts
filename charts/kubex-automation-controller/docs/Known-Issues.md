# Known Issues

This document lists current known issues, limitations, and their status in the Kubex Automation Controller.

# Quick Links

- [Known Issues](#known-issues)
- [Quick Links](#quick-links)
  - [Container Optimization Issues](#container-optimization-issues)
    - [Redundant Processing of Correctly Sized Containers](#redundant-processing-of-correctly-sized-containers)
    - [Single-Threaded Pod Processing](#single-threaded-pod-processing)
    - [Container Resize Decision Reasoning Not Exposed](#container-resize-decision-reasoning-not-exposed)
    - [Pod Eviction Order Not Optimized](#pod-eviction-order-not-optimized)
  - [Policy and Configuration Issues](#policy-and-configuration-issues)
    - [Scope Selector Requirements Too Restrictive](#scope-selector-requirements-too-restrictive)
    - [Resource Optimization May Temporarily Exceed Quotas During Pod Replacement](#resource-optimization-may-temporarily-exceed-quotas-during-pod-replacement)
    - [LimitRange maxLimitRequestRatio Not Supported](#limitrange-maxlimitrequestratio-not-supported)
  - [Storage and Deployment Issues](#storage-and-deployment-issues)
    - [Valkey Password Special Character Limitations](#valkey-password-special-character-limitations)

---

## Container Optimization Issues

### Redundant Processing of Correctly Sized Containers
**Status**: Performance Limitation 

**Description**: Controller performs full policy evaluation and sizing checks on all containers during each reconciliation cycle, including those already correctly sized  

**Impact**: Unnecessary CPU and API overhead in large clusters with many correctly optimized containers  

**Root Cause**: Current reconciliation loop lacks optimization to skip containers that don't require changes  

**Planned Fix**: Enhanced reconciliation logic to skip unnecessary checks for correctly sized containers

### Single-Threaded Pod Processing
**Status**: Current Design Choice  

**Description**: Controller processes pods sequentially (one at a time) rather than in parallel batches  

**Benefits**: Simplified troubleshooting, predictable log ordering, reduced cluster API load, easier confidence building during initial deployments  

**Impact**: Longer processing time in clusters with thousands of pods  

**Future Enhancement**: Optional multi-threaded processing mode for high-scale environments (planned for future release)

### Container Resize Decision Reasoning Not Exposed
**Status**: Known Limitation  

**Description**: When containers are not resized, the specific reason (policy restrictions, safety checks, etc.) is not explicitly surfaced to users  

**Impact**: Users must manually dig through controller logs to understand why expected optimizations didn't occur

**Root Cause**: Decision reasoning is logged but not exposed through annotations, events, or status fields 

**Planned Fix**: Enhanced visibility through container annotations and via Kubex UI

### Pod Eviction Order Not Optimized
**Status**: Partially Improved  

**Description**: Controller evicts pods for resizing based on discovery order rather than using fully intelligent prioritization, though recent improvements have been made  

**Recent Improvements**: 
- **Randomized namespace ordering**: Each scan cycle processes namespaces in random order to prevent consistently prioritizing the same namespaces
- **Configurable pod randomization**: Optional randomization of pod selection within each namespace (disabled by default)
  
**Current Behavior**: Pod randomization is disabled by default to allow pods with the same pod owner (Deployment, StatefulSet, etc.) to be processed together for operational consistency  

**Impact**: While namespace randomization helps distribute processing, high-impact optimizations may still be delayed if lower-priority pods are processed first within namespaces  

**Root Cause**: Current implementation lacks logic to prioritize pods by optimization impact, criticality, or production priority classes  

**Future Enhancement**: Smart eviction ordering based on optimization impact, pod priority classes, and user-defined criteria

## Policy and Configuration Issues

### Scope Selector Requirements Too Restrictive
**Status**: Known Limitation  

**Description**: Scope configuration has multiple current limitations:
- Both namespace selectors and podLabel selectors are mandatory fields, even when only one type of filtering is needed
- Selector operations are limited to `In` and `NotIn` only - other Kubernetes label selector operations (Exists, DoesNotExist, etc.) are not supported
  
**Impact**: Some complex filtering scenarios may be difficult to express with current selector limitations  

**Workaround**: 
- Define placeholder podLabel selectors when only namespace filtering is needed
- Use creative combinations of `In`/`NotIn` operations to achieve desired filtering where possible
  
**Future Enhancement**: Additional selector operations will only be considered if customers demonstrate that their scope requirements cannot be adequately defined with current `In`/`NotIn` operations


### Resource Optimization May Temporarily Exceed Quotas During Pod Replacement
**Status**: Known Limitation  

**Description**: During pod eviction and recreation with new resource values, there may be brief periods where both old and new pods exist, potentially exceeding namespace resource quotas

**Impact**: Pod creation may fail due to quota limits during the replacement window. This is more likely to occur when using very short `podEvictionCooldownPeriod` values (< 15s)

**Root Cause**: Kubernetes pod replacement is not atomic - new pod is created before old pod is fully terminated

**Mitigation**: Default `podEvictionCooldownPeriod` of 1m helps reduce this issue by allowing more time for pod termination before the next eviction

**Workaround**: Ensure resource quotas have sufficient headroom to accommodate temporary pod duplication during replacement, especially when using aggressive cooldown periods

### LimitRange maxLimitRequestRatio Not Supported
**Status**: Known Limitation  

**Description**: Controller does not currently validate or respect the `maxLimitRequestRatio` field in LimitRange objects when performing resource optimizations  

**Impact**: May apply resource changes that violate LimitRange ratio constraints, potentially causing pod admission failures  

**Root Cause**: Current validation logic only checks min/max values but ignores ratio constraints between limits and requests  

**Workaround**: Exclude namespaces containing LimitRange objects with `maxLimitRequestRatio` constraints from your automation scope configuration 

**Planned Fix**: Enhanced LimitRange validation to include maxLimitRequestRatio constraint checking

## Storage and Deployment Issues

### Valkey Password Special Character Limitations
**Status**: Known Limitation  

**Description**: Valkey passwords containing spaces or certain special characters cause authentication failures  

**Impact**: Installation failures with specific password patterns  

**Workaround**: Use passwords with alphanumeric and basic special characters only (no spaces)  

**Planned Fix**: Enhanced password validation and encoding