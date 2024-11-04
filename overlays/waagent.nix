# Override python version of waagent

{ inputs }:

self: super: {
  waagent = (super.waagent.override {
    python39 = super.python310;
  });
}
