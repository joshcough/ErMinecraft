import sbt._
import Keys._
import java.io.File
import com.joshcough.minecraft.Plugin._
import sbtassembly.Plugin._
import AssemblyKeys._

object build extends Build {

  val projectUrl = "https://github.com/joshcough/NetLogoMinecraft"

  lazy val standardSettings = join(
    Defaults.defaultSettings,
    bintray.Plugin.bintraySettings,
    libDeps(
      "javax.servlet"      % "servlet-api" % "2.5"        % "provided->default",
      "org.scalacheck"    %% "scalacheck"  % "1.11.3"     % "test",
      "org.bukkit"         % "bukkit" % "1.7.2-R0.2",
      "com.joshcough"     %% "scala-minecraft-plugin-api" % "0.3.3"
    ),
    Seq(
      organization := "com.joshcough",
      version := "0.3.3",
      scalaVersion := "2.11.0",
      licenses <++= version(v => Seq("MIT" -> url(projectUrl + "/blob/%s/LICENSE".format(v)))),
      publishMavenStyle := true,
      resolvers += Resolver.sonatypeRepo("snapshots"),
      resolvers += "Bukkit" at "http://repo.bukkit.org/content/repositories/releases"
    )
  )

  // this is the main project, that builds all subprojects.
  // it doesnt contain any code itself.
  lazy val all = Project(
    id = "all",
    base = file("."),
    settings = standardSettings,
    aggregate = Seq(erminecraft, ermineLibPlugin)
  )

  // ErmineCraft stuff below.
  val repl = InputKey[Unit]("repl", "Run the Ermine read-eval-print loop")
  val allUnmanagedResourceDirectories = SettingKey[Seq[File]](
    "all-unmanaged-resource-directories",
    "unmanaged-resource-directories, transitively."
  )
  /** Multiply a setting across Compile, Test, Runtime. */
  def compileTestRuntime[A](f: Configuration => Setting[A]): SettingsDefinition =
    seq(f(Compile), f(Test), f(Runtime))
  lazy val ermineFileSettings = Defaults.defaultSettings ++ Seq[SettingsDefinition](
    compileTestRuntime(sc => classpathConfiguration in sc := sc)
    ,mainClass in (Compile, run) := Some("com.clarifi.reporting.ermine.session.Console")
    ,compileTestRuntime(sco => allUnmanagedResourceDirectories in sco <<=
      Defaults.inDependencies(unmanagedResourceDirectories in sco, _ => Seq.empty)
        (_.reverse.flatten))
    // Usually, resources end up in the classpath by virtue of `compile'
    // copying them into target/scala-*/classes, and from there into jar.  But
    // we want in development p(1) I can edit an Ermine module in src
    // resources, hit reload, and it's seen. So we (harmlessly) patch the src resources
    // dirs in *before* the classes dirs, so they will win in the classloader
    // lookup.
    ,compileTestRuntime(sco =>
      fullClasspath in sco <<= (allUnmanagedResourceDirectories in sco, fullClasspath in sco) map {
        (urd, fc) => Attributed.blankSeq(urd) ++ fc
      })
  ) flatMap (_.settings)

  lazy val ermineSettings = join(
    standardSettings,
    ermineFileSettings,
    libDeps("com.clarifi" %% "ermine-legacy" % "0.1.1"),
    Seq(fullRunInputTask(repl, Compile, "com.clarifi.reporting.ermine.session.Console"))
  )

  lazy val erminecraft = Project(
    id = "erminecraft",
    base = file("erminecraft"),
    settings = join(ermineSettings, named("erminecraft-plugin-api"), copyPluginToBukkitSettings(None))
  )

  lazy val Zap = exampleErmineProject("Zap")

  def exampleErmineProject(exampleProjectName: String) = {
    val pluginClassname = "com.joshcough.minecraft.ermine.examples." + exampleProjectName
    Project(
      id = exampleProjectName,
      base = file("examples/" + exampleProjectName),
      settings = join(
        ermineSettings,
        named(exampleProjectName),
        pluginYmlSettings(pluginClassname, "JoshCough"),
        copyPluginToBukkitSettings(None),
        Seq(resourceGenerators in Compile <+= (baseDirectory, resourceManaged in Compile) map { (baseDir, outDir) =>
          IO.createDirectory(outDir / "modules")
          IO.copyDirectory(baseDir / "modules", outDir / "modules")
          (outDir / "modules").listFiles.toSeq
        })
      ),
      dependencies = Seq(erminecraft)
    )
  }

  // this project supplies the ermine language classes, and classes for all of ermine's dependencies.
  // it is needed in the bukkit plugins dir to run any ermine plugins.
  lazy val ermineLibPlugin = Project(
    id = "ermineLibPlugin",
    base = file("ermineLibPlugin"),
    settings = join(
      standardSettings,
      assemblySettings,
      copyPluginToBukkitSettings(Some("assembly")),
      named("erminecraft-ermine-library"),
      libDeps(
        "com.clarifi" %% "ermine-legacy"     % "0.1.1",
        "org.scalaz"  %% "scalaz-core"       % "7.0.6",
        "org.scalaz"  %% "scalaz-concurrent" % "7.0.6",
        "org.scalaz"  %% "scalaz-effect"     % "7.0.6",
        "org.scalaz"  %% "scalaz-iterv"      % "7.0.6",
        "log4j"       %  "log4j"             % "1.2.14"
      )
    )
  )

}
