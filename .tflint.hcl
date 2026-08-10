config {
  call_module_type = "local"
}

# No official tencentcloud ruleset exists; the built-in terraform language
# ruleset still enforces documentation, naming and syntax conventions.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
