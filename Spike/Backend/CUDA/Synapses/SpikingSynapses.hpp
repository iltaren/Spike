#pragma once

#include "Spike/Synapses/SpikingSynapses.hpp"
#include "Synapses.hpp"
#include "Spike/Backend/CUDA/CUDABackend.hpp"
#include <cuda.h>
#include <vector_types.h>
#include <curand.h>
#include <curand_kernel.h>

namespace Backend {
  namespace CUDA {
    class SpikingSynapses : public virtual ::Backend::CUDA::Synapses,
                            public virtual ::Backend::SpikingSynapses {
    public:
      // Device pointers
      int* delays = nullptr;
      bool* stdp = nullptr;
      int* spikes_travelling_to_synapse = nullptr;
      float* time_of_last_spike_to_reach_synapse = nullptr;

      ~SpikingSynapses();
      using ::Backend::SpikingSynapses::frontend;

      // NB: If we override Synapses::prepare, make sure to call it as well
      //      -- it initializes the random_state_manager_backend pointer!
      // void prepare() {} 
      void reset_state() override;

      void allocate_device_pointers() override;
      void copy_constants_and_initial_efficacies_to_device() override;
      // void set_threads_per_block_and_blocks_per_grid(int threads) override;

      // virtual void interact_spikes_with_synapses(SpikingNeurons * neurons, SpikingNeurons * input_neurons, float current_time_in_seconds, float timestep) override;

      virtual void interact_spikes_with_synapses(::SpikingNeurons * neurons, ::SpikingNeurons * input_neurons, float current_time_in_seconds, float timestep);

      void push_data_front() override;
    };

    __global__ void move_spikes_towards_synapses_kernel(int* d_presynaptic_neuron_indices,
                                                        int* d_delays,
                                                        int* d_spikes_travelling_to_synapse,
                                                        float* d_neurons_last_spike_time,
                                                        float* d_input_neurons_last_spike_time,
                                                        float currtime,
                                                        size_t total_number_of_synapses,
                                                        float* d_time_of_last_spike_to_reach_synapse);

    __global__ void check_bitarray_for_presynaptic_neuron_spikes(int* d_presynaptic_neuron_indices,
                                                                 int* d_delays,
                                                                 unsigned char* d_bitarray_of_neuron_spikes,
                                                                 unsigned char* d_input_neuruon_bitarray_of_neuron_spikes,
                                                                 int bitarray_length,
                                                                 int bitarray_maximum_axonal_delay_in_timesteps,
                                                                 float current_time_in_seconds,
                                                                 float timestep,
                                                                 size_t total_number_of_synapses,
                                                                 float* d_time_of_last_spike_to_reach_synapse);
  }
}
