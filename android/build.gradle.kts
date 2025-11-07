allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix for flutter_wear_os_connectivity namespace issue
subprojects {
    afterEvaluate {
        if (project.name == "flutter_wear_os_connectivity") {
            android {
                namespace = "github.ssttonn.flutter_wear_os_connectivity"
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
