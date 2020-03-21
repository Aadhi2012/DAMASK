import os
import subprocess
import shlex
import string

from .._environment import Environment

class Marc:
    """Wrapper to run DAMASK with MSCMarc."""

    def __init__(self,version=Environment().options['MARC_VERSION']):
        """
        Create a Marc solver object.

        Parameters
        ----------
        version : float
            Marc version

        """
        self.solver  = 'Marc'
        try:
            self.version = int(version)
        except TypeError:
            self.version = -1


#--------------------------
    def libraryPath(self):

        path_MSC = Environment().options['MSC_ROOT']
        path_lib = '{}/mentat{}/shlib/linux64'.format(path_MSC,self.version)

        return path_lib if os.path.exists(path_lib) else ''


#--------------------------
    def toolsPath(self):

        path_MSC   = Environment().options['MSC_ROOT']
        path_tools = '{}/marc{}/tools'.format(path_MSC,self.version)

        return path_tools if os.path.exists(path_tools) else ''


#--------------------------
    def submit_job(self,
                   model,
                   job          = 'job1',
                   logfile      = False,
                   compile      = False,
                   optimization = '',
                  ):


        damaskEnv = Environment()

        user = os.path.join(damaskEnv.relPath('src'),'DAMASK_marc{}.{}'.format(self.version,'f90' if compile else 'marc'))
        if not os.path.isfile(user):
            raise FileNotFoundError("DAMASK4Marc ({}) '{}' not found".format(('source' if compile else 'binary'),user))

        # Define options [see Marc Installation and Operation Guide, pp 23]
        script = 'run_damask_{}mp'.format(optimization)

        cmd = os.path.join(self.toolsPath(),script) + \
              ' -jid ' + model + '_' + job + \
              ' -nprocd 1  -autorst 0 -ci n  -cr n  -dcoup 0 -b no -v no'

        if compile: cmd += ' -u ' + user + ' -save y'
        else:       cmd += ' -prog ' + os.path.splitext(user)[0]

        print('job submission {} compilation: {}'.format('with' if compile else 'without',user))
        if logfile: log = open(logfile, 'w')
        print(cmd)
        process = subprocess.Popen(shlex.split(cmd),stdout = log,stderr = subprocess.STDOUT)
        log.close()
        process.wait()

#--------------------------
    def exit_number_from_outFile(self,outFile=None):
        exitnumber = -1
        with open(outFile,'r') as fid_out:
            for line in fid_out:
                if (string.find(line,'tress iteration') != -1):
                    print(line)
                elif (string.find(line,'Exit number')   != -1):
                    substr = line[string.find(line,'Exit number'):len(line)]
                    exitnumber = int(substr[12:16])

        return exitnumber
