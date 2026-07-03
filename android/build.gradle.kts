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
}

// 第三方插件的 Java/Kotlin JVM target 各不相同（如 flutter_timezone 为 1.8/11、
// android_alarm_manager_plus 为 17），会触发 "Inconsistent JVM Target" 构建失败，
// 这里把所有子项目的 Java 与 Kotlin 统一对齐到 17。
// flutter_timezone 3.x 的 Kotlin jvmTarget(1.8) 与其 Java target(11) 不一致，
// 触发 "Inconsistent JVM Target" 构建失败，这里把它的 Kotlin target 对齐到 11。
project(":flutter_timezone") {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
