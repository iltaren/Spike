#ifndef ImagePoissonSpikingNeurons_H
#define ImagePoissonSpikingNeurons_H

#include <cuda.h>
#include <curand.h>
#include <curand_kernel.h>

#include "PoissonSpikingNeurons.h"

#include <vector>

using namespace std;

struct image_poisson_spiking_neuron_parameters_struct : poisson_spiking_neuron_parameters_struct {
	image_poisson_spiking_neuron_parameters_struct() { poisson_spiking_neuron_parameters_struct(); }
};


class ImagePoissonSpikingNeurons : public PoissonSpikingNeurons {
public:
	// Constructor/Destructor
	ImagePoissonSpikingNeurons();
	~ImagePoissonSpikingNeurons();

	virtual int AddGroup(neuron_parameters_struct * group_params, int group_shape[2]);
	virtual void allocate_device_pointers();
	virtual void reset_neurons();

	void image_test();
	void loadFileList(const char * fileList);
	void loadInput(const char * inputDirectory);

	vector<string> inputNames;

};

#endif