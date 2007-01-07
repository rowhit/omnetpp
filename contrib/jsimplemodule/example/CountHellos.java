import org.omnetpp.simkernel.*;

/**
 * Forwards messages from several inputs to one output.
 */
public class CountHellos extends JSimpleModule {

    protected long counter = 0;

    protected void handleMessage(cMessage msg) {
        if (HelloMessage.castFrom(msg) != null) {
            ev.println("here's one Hello! seen " + counter + " already!");
            ++counter;

            HelloMessage hello = HelloMessage.castFrom(msg);
            ev.println("it says: " + hello.getText());
        }
        send(msg, "out");
    }

    protected void finish() {
        recordScalar("hellos seen", counter);
    }

};




