

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
		// sortet buildings by area
		let sorted_buildings <- reverse(building sort_by (each.shape.area));
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

	reflex check_all_informed_evacuated {
	// Đếm số lượng cư dân đã được thông báo nhưng chưa sơ tán
		int remaining_informed <- length(inhabitant where (each.isInformed and not each.isEvacuated));
		int remaining_evacuated <- length(inhabitant where (each.isEvacuated));
		// Nếu không còn cư dân nào chưa sơ tán, tạm dừng mô phỏng
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
			color <- #green; // Màu sắc cho người đã sơ tán tới nơi trú ẩn
		} else if (isEvacuating) {
			color <- #orange;
		} else if (isInformed) {
			color <- #red;
		} else {
			color <- #cyan;
		}

		draw circle(5) color: color;
	}

	reflex update_status {
		if (isInformed and not isEvacuating) {
			isEvacuating <- true;
			building nearestShelter <- one_of(shelters closest_to location);
			if (nearestShelter != nil) {
				target <- nearestShelter.location;
			}

		} else if (not isInformed) {
			list<inhabitant> nearbyEvacuating <- list(inhabitant at_distance 10) where (each.isEvacuating);
			if (length(nearbyEvacuating) > 0 and flip(0.1)) {
				isInformed <- true;
				isEvacuating <- true;
				building nearestShelter <- one_of(shelters closest_to location);
				if (nearestShelter != nil) {
					target <- nearestShelter.location;
				}

			}

		}

	}

	reflex decise_target when: target = nil {
		if (isInformed and isEvacuating) {
			building nearestShelter <- one_of(shelters closest_to location);
			if (nearestShelter != nil) {
				target <- nearestShelter.location;
			}

		} else if (not isInformed and not isEvacuating) {
		// random moving
			building randomBuilding <- one_of(building);
			if (randomBuilding != nil) {
				target <- randomBuilding.location;
			}

		}

	}

	reflex move {
		if ((not isEvacuated) and target != nil) {
			do goto target: target on: road_network;
			if (location = target) {
				target <- nil; // stop if inhabitant is in the shelter
				if (isEvacuating) {
					isEvacuated <- true; // Cập nhật trạng thái isEvacuated
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
		monitor "Not Informed Population" value: length(inhabitant where (not each.isInformed));
		monitor "Evacuated Population" value: length(inhabitant where (each.isEvacuated));
		monitor "Number of Shelter" value: length(building where (each.isShelter));
	}

}
