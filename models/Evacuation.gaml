

/**
* Name: Evacuation
* Based on the internal empty template. 
* Author: hangoclinh
* Tags: 
*/
model Evacuation

global {
	int population_size <- 1000;
	int neighbours_distance <- 10;
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
	float evacuationRadius <- 10.0; // Khoảng cách quan sát người khác sơ tán
	float evacuateProbability <- 0.1; // Xác suất bắt đầu sơ tán sau khi quan sát
	list<resident> neighbours update: resident at_distance neighbours_distance;
	// Được gọi mỗi chu kỳ để cập nhật trạng thái thông tin và quyết định sơ tán
	reflex update_status {
	// Nếu cư dân đã được thông báo và chưa bắt đầu sơ tán
		if (isInformed and not isEvacuating) {
			isEvacuating <- true;
		} else if (not isInformed) {
		// Kiểm tra xem có cư dân nào đang sơ tán trong phạm vi quan sát không
			loop other over: neighbours {
				if (other.isEvacuating and flip(evacuateProbability)) {
					isInformed <- true;
					isEvacuating <- true;
					break;
				}

			}

		}

	}

	// Di chuyển đến nơi trú ẩn nếu cư dân bắt đầu sơ tán
	reflex move_towards_shelter {
		if (isEvacuating) {
			do goto target: shelter_location;
		}

	}

}

experiment EvacuationExp type: gui {
// Experiment setup and visualization
}