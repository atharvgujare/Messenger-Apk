allprojects {
    repositories {
        google()
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
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
    val proj = this
    if (proj.name != "app") {
        proj.afterEvaluate {
            val android = proj.extensions.findByName("android")
            if (android != null) {
                for (m in android.javaClass.methods) {
                    if (m.name == "compileSdkVersion" || m.name == "setCompileSdk" || m.name == "setCompileSdkVersion") {
                        try {
                            if (m.parameterTypes.size == 1) {
                                if (m.parameterTypes[0] == Int::class.javaPrimitiveType || m.parameterTypes[0] == java.lang.Integer::class.java) {
                                    m.invoke(android, 36)
                                    println("[MessengerGradle] Set compileSdk 36 on ${proj.name} via ${m.name}")
                                }
                            }
                        } catch (_: Exception) {}
                    }
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
