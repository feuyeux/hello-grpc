import org.gradle.api.plugins.JavaPluginExtension

plugins {
    id("java-library")
}

extensions.configure<JavaPluginExtension>("java") {
    // Point to the central proto directory instead of local one
    sourceSets.getByName("main").resources.srcDir("../../proto")
}
