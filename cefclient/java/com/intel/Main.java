package com.intel;

public class Main {

    boolean isStopped = true;

    private class internalRoutine  extends Thread {

        Main parent;

        internalRoutine( Main parent)
        {
            this.parent = parent;
        }


        public void run() {
            System.out.println("Routine thread!");

            while (true)
            {
                if (parent.isStopped) break;

                try {
                    parent.updateJS();
                    sleep(1000);

                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
    }

    public static void main(String[] args) {

        System.out.println("Hello from Java!!!");

        Main main = new Main();

        main.run();

        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        main.stop();

        System.out.println("Finished");
    }

    public void run() {

        System.out.println("[ RUN ]");

        isStopped = false;

        (new internalRoutine(this)).start();
    }

    public void stop() {

        System.out.println("[ STOP ]");

        isStopped = true;
    }

    native void updateJS();

}
