# Override python version of waagent

{ inputs, ... }:
self: super: {
  waagent = (super.waagent.override {
    python3 = super.python311;
  });
}
