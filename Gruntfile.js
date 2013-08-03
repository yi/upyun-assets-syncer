'use strict';

module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({

    simplemocha: {
      options: {
        globals: ['should'],
          timeout: 3000,
          ignoreLeaks: false,
          grep: '*-test',
          ui: 'bdd',
          reporter: 'tap'
        },

        all: { src: ['test/**/*.js'] }
    },
    watch: {
      gruntfile: {
        files: '<%= jshint.gruntfile.src %>',
        tasks: ['jshint:gruntfile']
      },
      lib: {
        files: '<%= jshint.lib.src %>',
        tasks: ['jshint:lib', 'nodeunit']
      },
      test: {
        files: '<%= jshint.test.src %>',
        tasks: ['jshint:test', 'nodeunit']
      }
    }
  });

  // These plugins provide necessary tasks.
  grunt.loadNpmTasks('grunt-simple-mocha');
  grunt.loadNpmTasks('grunt-contrib-watch');

  // Default task.
  grunt.registerTask('default', ['simplemocha']);

};
