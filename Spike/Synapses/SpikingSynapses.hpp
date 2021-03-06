#ifndef SPIKINGSYNAPSES_H
#define SPIKINGSYNAPSES_H

class SpikingSynapses; // forward definition

#include "Synapses.hpp"
#include "Spike/Models/SpikingModel.hpp"
#include "Spike/Neurons/SpikingNeurons.hpp"
#include <vector>

namespace Backend {
  class SpikingSynapses : public virtual Synapses {
  public:
    SPIKE_ADD_BACKEND_FACTORY(SpikingSynapses);
    virtual void copy_weights_to_host() = 0;
    virtual void state_update(unsigned int current_time_in_timesteps, float timestep) = 0;
  };
}

struct spiking_synapse_parameters_struct : synapse_parameters_struct {
  float delay_range[2];
  std::vector<float> pairwise_connect_delay;
};

class SpikingSynapses : public Synapses {
public:
  SpikingSynapses() : Synapses() {};
  SpikingSynapses(int seedval) : Synapses(seedval) {};
  ~SpikingSynapses() override;

  SPIKE_ADD_BACKEND_GETSET(SpikingSynapses, Synapses);
  void init_backend(Context* ctx = _global_ctx) override;
  void prepare_backend_early() override;

  // Host Pointers
  int* delays = nullptr;
  SpikingModel* model = nullptr;

  // For spike array stuff
  int minimum_axonal_delay_in_timesteps = pow(10, 6);
  int maximum_axonal_delay_in_timesteps = 0;
  int neuron_pop_size = 0; // parameter for efficient conductance trace

  // In order to group synapses, give them a distinction
  int num_syn_labels = 1;
  int* syn_labels = nullptr;

  // Synapse Functions
  int AddGroup(int presynaptic_group_id, 
                int postsynaptic_group_id, 
                Neurons * neurons,
                Neurons * input_neurons,
                float timestep,
                synapse_parameters_struct * synapse_params) override;

  void increment_number_of_synapses(int increment);
  void sort_synapses();
  void set_synapse_start(int pre_index, int syn_start);

  virtual void state_update(unsigned int current_time_in_timesteps, float timestep);

  virtual void save_connectivity_as_txt(std::string path, std::string prefix="", int synapsegroupid=-1) override;
  virtual void save_connectivity_as_binary(std::string path, std::string prefix="",int synapsegroupid=-1) override;
private:
  std::shared_ptr<::Backend::SpikingSynapses> _backend;
};

#endif
