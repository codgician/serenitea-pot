{ inputs, system, ... }:

_final: _prev: {
  llm-agents = inputs.llm-agents.packages.${system} or { };
}
