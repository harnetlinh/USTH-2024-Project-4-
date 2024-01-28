

/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation



global {
	int population_size <- 1000;
	geometry shelter_location; // Define the location of the shelter
	init {
	// Initialize residents and the shelter
	// Randomly inform 10% of the population
	}

}

species resident skills: [moving] {
    bool isInformed <- false;
    bool isEvacuating <- false;
    point home;
    point location <- home;
    float evacuationRadius <- 10.0; // Radius to observe others evacuating
    float evacuateProb <- 0.1; // Probability to evacuate upon observation

    reflex become_informed {
        if (isInformed) {
            isEvacuating <- true;
            do goto target: shelter_location;
        }
    }

    reflex observe_and_decide {
        if (not isInformed) {
            // Check if there are any evacuating residents within evacuationRadius
            list<resident> nearbyEvacuatingResidents <- self.neighbors_of(radius: evacuationRadius, where: (each.isEvacuating));
            if (not empty(nearbyEvacuatingResidents) and flip(evacuateProb)) {
                isInformed <- true;
            }
        }
    }

    reflex move {
        if (isEvacuating and location != shelter_location) {
            do goto target: shelter_location;
        }
    }
}


experiment EvacuationExp type: gui {
// Experiment setup and visualization
}