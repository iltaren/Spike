#include "SpikingSynapses.hpp"

SPIKE_EXPORT_BACKEND_TYPE(Dummy, SpikingSynapses);

namespace Backend {
  namespace Dummy {
    SpikingSynapses::SpikingSynapses() {
    }
    void SpikingSynapses::prepare() {
      Synapses::prepare();
    }

    void SpikingSynapses::reset_state() {
      Synapses::reset_state();
    }

    void SpikingSynapses::state_update
    (unsigned int current_time_in_timesteps, float timestep) {
    }

    void SpikingSynapses::copy_weights_to_host() {
    }
  }
}
