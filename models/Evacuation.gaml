

/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation

global {
	int population_size <- 1000 parameter: "population size";
	int num_shelter <- 1 parameter: "Number of shelter";
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/clean_roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	float step <- 10 #s;
	list<building> shelters; // List shelters
	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		road_network <- as_edge_graph(road);
		// sorted buildings by area
		let sorted_buildings <- reverse(building sort_by (each.shape.area));
		//		set the largest building to be the shelter
		loop i from: 0 to: (num_shelter - 1) {
			sorted_buildings[i].isShelter <- true;
		}

		shelters <- building where (each.isShelter);
		let non_shelter_buildings <- building where (not each.isShelter); // prevent any inhabitant in the shelter
		create inhabitant number: population_size {
			home <- any_location_in(one_of(non_shelter_buildings));
			location <- home;
			isInformed <- flip(0.1);
		}

	}

	reflex update_speed {
		ask road {
			speed_rate <- max(exp(-length(inhabitant at_distance 1) / (1 + shape.perimeter / 10)), 0.1);
		}

	}

	reflex simulation_running_condition {
		int remaining_informed <- length(inhabitant where (each.isInformed or each.isEvacuating));
		int remaining_evacuated <- length(inhabitant where (each.isEvacuated));
		// If there is no body know about the infor and evacutation or all inhabitant have been evacuated
		if (remaining_informed = 0 or remaining_evacuated = population_size) {
			do pause;
		}

	}

}

species building {
	int height;
	bool isShelter <- false;

	aspect default {
		if (isShelter) {
			draw circle(20) color: #green;
		} else {
			draw shape color: #gray;
		}

	}

}

species road {
	float speed_rate;
	int nb_inhabitants <- 0 update: length(inhabitant at_distance 1);

	reflex update_speed_rate {
		speed_rate <- max(exp(-nb_inhabitants / (1 + shape.perimeter / 10)), 0.1);
	}

	aspect default {
		draw shape color: #black;
	}

}

species inhabitant skills: [moving] {
	bool isInformed <- false;
	bool isEvacuating <- false;
	bool isEvacuated <- false;
	point home;
	point target;
	point location <- home;

	aspect default {
		rgb color;
		if (isEvacuated) {
			color <- #green;
		} else if (isEvacuating) {
			color <- #orange;
		} else if (isInformed) {
			color <- #red;
		} else {
			color <- #cyan;
		}

		draw circle(5) color: color;
	}

	reflex inform_evacuating when: (not isInformed and not isEvacuating and not isEvacuated) {
		list<inhabitant> nearbyEvacuating <- list(inhabitant at_distance 10) where (each.isInformed or each.isEvacuating);
		// if an habitant who is not informed near an evacuating inhabitant, he will be informed with 10% chance
		if (length(nearbyEvacuating) > 0 and flip(0.1)) {
			isInformed <- true;
			building nearestShelter <- one_of(shelters closest_to location);
			if (nearestShelter != nil) {
				target <- nearestShelter.location;
				isEvacuating <- true;
				isInformed <- false;
			}

		}

	}

	reflex just_moving when: target = nil and (not isInformed and not isEvacuating and not isEvacuated) {

	// random moving
		building randomBuilding <- one_of(building where not each.isShelter);
		if (randomBuilding != nil) {
			target <- randomBuilding.location;
		}

	}

	reflex evacuated when: isEvacuated {
		target <- nil;
		isEvacuating <- false;
		isInformed <- false;
	}

	reflex isInformed when: isInformed and target = nil {
		isEvacuating <- true;
		isInformed <- false;
		building nearestShelter <- one_of(shelters closest_to location);
		if (nearestShelter != nil) {
			target <- nearestShelter.location;
		}

	}

	reflex move {
		if ((not isEvacuated) and target != nil) {
			do goto target: target on: road_network;
			if (location = target) {
				target <- nil; // stop if inhabitant is in the shelter
				if (isEvacuating) {
					isEvacuated <- true;
					isEvacuating <- false;
				}

			}

		}

	} }

experiment EvacuationExperiment type: gui {
	output {
		display PopulationMap type: opengl {
			species building;
			species road;
			species inhabitant aspect: default;
		}

		monitor "Evacuating Population" value: length(inhabitant where (each.isEvacuating));
		monitor "Informed Population" value: length(inhabitant where (each.isInformed));
		monitor "Not Informed Population" value: length(inhabitant where (not each.isInformed and not each.isEvacuating and not each.isEvacuated));
		monitor "Evacuated Population" value: length(inhabitant where (each.isEvacuated));
		monitor "Number of Shelter" value: length(building where (each.isShelter));
	}

}
