allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    configurations.all {
        resolutionStrategy {
            // Enforce 16 KB ELF PT_LOAD page alignment for ML Kit & CameraX native .so libs
            force(
                "com.google.mlkit:barcode-scanning:17.3.0",
                "androidx.camera:camera-core:1.4.1",
                "androidx.camera:camera-camera2:1.4.1",
                "androidx.camera:camera-lifecycle:1.4.1",
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
