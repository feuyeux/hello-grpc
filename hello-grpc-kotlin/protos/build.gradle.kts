plugins {
    `java-library`
}

java {
    // Point to the central proto directory instead of local one
    sourceSets.getByName("main").resources.srcDir("../../proto")
}
