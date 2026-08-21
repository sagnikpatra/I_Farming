## The deliberate no-op CloudSaveProvider -- what every save-flow call site
## uses until a real backend (adr-0003) is chosen and its Phase 1 spike
## lands. Functionally identical to the base CloudSaveProvider class (every
## method already a no-op there); kept as its own named class so "this
## project currently has no cloud backend, on purpose" reads clearly at
## every call site and in tests, rather than callers constructing the bare
## interface class directly and leaving that intent implicit.
class_name NullCloudSaveProvider
extends CloudSaveProvider
