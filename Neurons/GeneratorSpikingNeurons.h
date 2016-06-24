#ifndef GeneratorSpikingNeurons_H
#define GeneratorSpikingNeurons_H

#include <cuda.h>
#include <curand.h>
#include <curand_kernel.h>

#include "InputSpikingNeurons.h"

struct generator_spiking_neuron_parameters_struct : input_spiking_neuron_parameters_struct {
	generator_spiking_neuron_parameters_struct() { input_spiking_neuron_parameters_struct(); }
};

class GeneratorSpikingNeurons : public InputSpikingNeurons {
public:
	// Constructor/Destructor
	GeneratorSpikingNeurons();
	~GeneratorSpikingNeurons();

	int** neuron_id_matrix_for_stimuli;
	float** spike_times_matrix_for_stimuli;
	int* number_of_spikes_in_stimuli;

	int* d_neuron_ids_for_stimulus;
	float* d_spike_times_for_stimulus;

	int length_of_longest_stimulus;

	
	// Functions
	virtual int AddGroup(neuron_parameters_struct * group_params);
	virtual void allocate_device_pointers();
	virtual void reset_neurons();
	virtual void set_threads_per_block_and_blocks_per_grid(int threads);
	virtual void check_for_neuron_spikes(float current_time_in_seconds, float timestep);
	virtual void update_membrane_potentials(float timestep);

	void AddStimulus(int spikenumber, int* ids, float* spiketimes);
};


__global__ void check_for_generator_spikes_kernel(int *d_neuron_ids_for_stimulus,
								float *d_spike_times_for_stimulus,
								float* d_last_spike_time_of_each_neuron,
								float current_time_in_seconds,
								float timestep,
								size_t number_of_spikes_in_stimulus);

#endif