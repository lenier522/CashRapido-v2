buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.4")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force every sub-project (incl. plugins like apklis_license_validator that
    // bundle AGP 8.x in their own buildscript) to resolve the same AGP version
    // used by the host project.  Without this, the AGP 9.x version-check plugin
    // expects intermediate dirs (aar_metadata_check) that AGP 8.x never creates.
    buildscript {
        configurations.configureEach {
            resolutionStrategy {
                force("com.android.tools.build:gradle:9.1.0")
            }
        }
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
    val configureSdk: (Project) -> Unit = { p ->
        val android = p.extensions.findByName("android")
        if (android != null) {
            try {
                val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                method.invoke(android, 36)
            } catch (_: Exception) {
                try {
                    val method = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    method.invoke(android, 36)
                } catch (_: Exception) {}
            }
        }
    }
    if (state.executed) {
        configureSdk(this)
    } else {
        afterEvaluate {
            configureSdk(this)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
