/**
* Name: Evacuation_Extension1
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation_Extension1

/* Insert your model definition here */
global {
	int population_size <- 1000 parameter: "population size";
	int num_shelter <- 5 parameter: "Number of shelter";
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/clean_roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	float step <- 10 #s;
	list<building> shelters; // Danh sách các nơi trú ẩn
	init {
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		road_network <- as_edge_graph(road);

		// Chọn ngẫu nhiên một số lượng các nơi trú ẩn
		loop i from: 1 to: num_shelter {
			ask one_of(building) {
				isShelter <- true;
			}

		}

		shelters <- building where (each.isShelter);
		create inhabitant number: population_size {
			home <- any_location_in(one_of(building));
			location <- home;
			isInformed <- flip(0.1);
		}

	}

	reflex update_speed {
		ask road {
			speed_rate <- max(exp(-length(inhabitant at_distance 1) / (1 + shape.perimeter / 10)), 0.1);
		}

	}

}

species building {
	int height;
	bool isShelter <- false;

	aspect default {
		draw shape color: isShelter ? #yellow : #gray;
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
	point home;
	point target;
	point location <- home;

	aspect default {
		rgb color <- isInformed ? (isEvacuating ? #orange : #green) : #blue;
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
	// Nếu đã được thông báo hoặc đang sơ tán, hướng đến nơi trú ẩn gần nhất
		if (isInformed and isEvacuating) {
			building nearestShelter <- one_of(shelters closest_to location);
			if (nearestShelter != nil) {
				target <- nearestShelter.location;
			}

		} else {
		// Nếu không được thông báo và không đang sơ tán, chọn một tòa nhà ngẫu nhiên
			building randomBuilding <- one_of(building);
			if (randomBuilding != nil) {
				target <- randomBuilding.location;
			}

			// Kiểm tra nếu gần nơi trú ẩn (trong khoảng 20m)
			list<building> nearbyShelters <- list(building at_distance 10) where (each.isShelter);
			if (nearbyShelters != nil) {
				if (length(nearbyShelters) > 0) {
					isInformed <- true;
					isEvacuating <- true;
					target <- one_of(nearbyShelters).location;
				}

			}

		}

	}

	reflex move {
		if ((isEvacuating or (not isInformed)) and target != nil) {
			do goto target: target on: road_network;
			if (location = target) {
				target <- nil; // Dừng lại khi đến nơi trú ẩn
				isEvacuating <- false; // Cập nhật trạng thái không còn sơ tán
			}

		}

	}

}

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
		monitor "Evacuated Population" value: length(inhabitant where (each.isInformed and (not each.isEvacuating)));
		monitor "Number of Shelter" value: length(building where (each.isShelter));
	}

}
