package org.omnetpp.ned.editor.graph.misc;

import java.util.ArrayList;
import java.util.List;

import org.eclipse.core.runtime.Assert;
import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.MenuItem;
import org.omnetpp.ned.editor.graph.commands.ConnectionCommand;
import org.omnetpp.ned.model.NEDTreeUtil;
import org.omnetpp.ned.model.ex.CompoundModuleNodeEx;
import org.omnetpp.ned.model.ex.NEDElementFactoryEx;
import org.omnetpp.ned.model.ex.SubmoduleNodeEx;
import org.omnetpp.ned.model.interfaces.IHasConnections;
import org.omnetpp.ned.model.interfaces.INEDTypeInfo;
import org.omnetpp.ned.model.pojo.ConnectionNode;
import org.omnetpp.ned.model.pojo.GateNode;
import org.omnetpp.ned.model.pojo.NEDElementTags;

/**
 * Helper class that allows to choose a connection for a module pair (src, dest)
 *
 * @author rhornig
 */
public class ConnectionChooser {
    private static final String DEFAULT_INDEX = "0";

    // TODO implement popup menu if only one of the srcModule or destModule is present
    // only one side of the connection should be selected
    // TODO show which gates are already connected (do not offer those gates)
    /**
     * This method asks the user which gates should be connected on the source and
     * destination module.
     *
     * @param srcModule the source module we are connecting to, should not be NULL
     * @param srcGate which dest module gate should be offered. if NULL, all module gates will be enumerated
     * @param destModule the destination module we are connecting to, should not be NULL
     * @param destGate which dest module gate should be offered. if NULL, all module gates will be enumerated
     * @return TODO what does it return?
     */
    public static ConnectionNode open(ConnectionCommand connCommand) {
        Assert.isNotNull(connCommand.getSrcModule());
        Assert.isNotNull(connCommand.getDestModule());

        List<GateNode> srcOutModuleGates = getModuleGates(connCommand.getSrcModule(), GateNode.NED_GATETYPE_OUTPUT, connCommand.getSrcGate());
        List<GateNode> srcInOutModuleGates = getModuleGates(connCommand.getSrcModule(), GateNode.NED_GATETYPE_INOUT, connCommand.getSrcGate());
        List<GateNode> destInModuleGates = getModuleGates(connCommand.getDestModule(), GateNode.NED_GATETYPE_INPUT, connCommand.getDestGate());
        List<GateNode> destInOutModuleGates = getModuleGates(connCommand.getDestModule(), GateNode.NED_GATETYPE_INOUT, connCommand.getDestGate());

        BlockingMenu menu = new BlockingMenu(Display.getCurrent().getActiveShell(), SWT.NONE);

        // unidirectional connections
        for (GateNode srcOut : srcOutModuleGates)
            for (GateNode destIn : destInModuleGates)
                addConnectionPairsToMenu(connCommand, menu, srcOut, destIn);

        // bidirectional connections
        for (GateNode srcInOut : srcInOutModuleGates)
            for (GateNode destInOut : destInOutModuleGates)
                addConnectionPairsToMenu(connCommand, menu, srcInOut, destInOut);

        MenuItem selection = menu.open();
        if (selection == null)
            return null;

        return (ConnectionNode)selection.getData();
    }

    /**
     * Returns gates with the given type (in, out, inout) of the given compound module 
     * or submodule. If nameFilter is present (not null), the gate with that name is returned.
     */
    private static List<GateNode> getModuleGates(IHasConnections module, int gateType, String nameFilter) {
        List<GateNode> result = new ArrayList<GateNode>();

        if (module instanceof CompoundModuleNodeEx) {
            // if we connect a compound module, swap the gate type (in<>out) submodule.out -> out
            if (gateType == GateNode.NED_GATETYPE_INPUT)
                gateType = GateNode.NED_GATETYPE_OUTPUT;
            else if (gateType == GateNode.NED_GATETYPE_OUTPUT)
                gateType = GateNode.NED_GATETYPE_INPUT;
        }

        INEDTypeInfo typeInfo = module.getContainerNEDTypeInfo();
        Assert.isTrue(typeInfo != null);

        for (GateNode gate: typeInfo.getGates().values())
            if (gate.getType() == gateType)
                if (nameFilter == null || nameFilter.equals(gate.getName()))
                	result.add(gate);
        return result;
    }

    /**
     * @param connCommand The command used to specify which module and gates are to be used
     * @param menu The popup menu where the connection menu items should be added
     * @param srcGate The source gate used to create the connections
     * @param destGate The source gate used to create the connections
     */
    private static void addConnectionPairsToMenu(ConnectionCommand connCommand, BlockingMenu menu, GateNode srcGate, GateNode destGate) {
        int srcGatePPStart, srcGatePPEnd, destGatePPStart, destGatePPEnd;
        srcGatePPStart = destGatePPStart = 0;
        srcGatePPEnd = destGatePPEnd = 1;
        // check if we have specified the src or dest gate. in this case we don't have to offer ++ and [] indexted versions
        // we just have to use what is currently set on that gate
        if (connCommand.getSrcGate() != null)
            srcGatePPStart = srcGatePPEnd = (connCommand.getConnectionTemplate().getSrcGatePlusplus() ? 1 : 0);
        if (connCommand.getDestGate() != null)
            destGatePPStart = destGatePPEnd = (connCommand.getConnectionTemplate().getDestGatePlusplus() ? 1 : 0);

        // add the gate names to the menu item as additional widget data
        ConnectionNode conn;
        for (int srcGatePP = srcGatePPStart; srcGatePP<=srcGatePPEnd; srcGatePP++)
            for (int destGatePP = destGatePPStart; destGatePP<=destGatePPEnd; destGatePP++) {
                conn =  createTemplateConnection(connCommand.getSrcModule(), srcGate, srcGatePP==1,
                                                 connCommand.getDestModule(), destGate, destGatePP==1);
                if (conn != null) addConnectionToMenu(connCommand, menu, conn, srcGate, destGate);
            }
    }

    /**
	 * Creates a template connection object from the provided gates and modules.
	 * If the module is a vector, it uses module[0] syntax
	 * If the gate is a vector uses either gate[0] or gate++ syntax depending on the gatePP parameter.
	 * If the gatePP is set to <code>true</code> but none of the gates are vectors, it returns <code>null</code>
	 *
	 * @param srcMod
	 * @param srcGate
     * @param srcGatePP    if set to <code>true</code> creates gatename++ (only for vector gates)
	 * @param destMod
	 * @param destGate
	 * @param destGatePP 	if set to <code>true</code> creates gatename++ (only for vector gates)
	 * @return The template connection or <code>null</code> if connection cannot be created
	 */
	private static ConnectionNode createTemplateConnection(
						IHasConnections srcMod, GateNode srcGate, boolean srcGatePP,
						IHasConnections destMod, GateNode destGate, boolean destGatePP) {

		// check if at least one of the gates are vector if gatePP (gate++) syntax requested
        if (srcGatePP && !srcGate.getIsVector())
            return null;
		if (destGatePP && !destGate.getIsVector())
			return null;

		ConnectionNode conn = (ConnectionNode)NEDElementFactoryEx.getInstance().createNodeWithTag(NEDElementTags.NED_CONNECTION);
		// set the source and dest module names.
		// if compound module, name must be empty
		// for Submodules name must be the submodule name
		if (srcMod instanceof SubmoduleNodeEx) {
			SubmoduleNodeEx smodNode = (SubmoduleNodeEx)srcMod;
			conn.setSrcModule(smodNode.getName());
			if (smodNode.getVectorSize()!= null && !"".equals(smodNode.getVectorSize()))
					conn.setSrcModuleIndex(DEFAULT_INDEX);
		} else
			conn.setSrcModule(null);

		if (destMod instanceof SubmoduleNodeEx) {
			SubmoduleNodeEx dmodNode = (SubmoduleNodeEx)destMod;
			conn.setDestModule(dmodNode.getName());
			if (dmodNode.getVectorSize()!= null && !"".equals(dmodNode.getVectorSize()))
					conn.setDestModuleIndex(DEFAULT_INDEX);
		} else
			conn.setDestModule(null);

		// set the possible gates
		conn.setSrcGate(srcGate.getName());
		conn.setDestGate(destGate.getName());
		// if both side is bidirectional gate, use a bidirectional connection
		if (srcGate.getType() == GateNode.NED_GATETYPE_INOUT && destGate.getType() == GateNode.NED_GATETYPE_INOUT)
			conn.setArrowDirection(ConnectionNode.NED_ARROWDIR_BIDIR);
		else
			conn.setArrowDirection(ConnectionNode.NED_ARROWDIR_L2R);

		// check if we have a module vector and add an index to it.
		if (srcGate.getIsVector())
			if (srcGatePP)
				conn.setSrcGatePlusplus(true);
			else
				conn.setSrcGateIndex(DEFAULT_INDEX);

		if (destGate.getIsVector())
			if (destGatePP)
				conn.setDestGatePlusplus(true);
			else
				conn.setDestGateIndex(DEFAULT_INDEX);

		return conn;
	}

    /**
     * Add the provided TemplateConnection to the menu,
     * @param connCommand The original connection command we want to specify
     * @param menu
     * @param conn A single connection that should be added to the menu
     * @param srcGate The source gate we are connecting/connected to
     * @param destGate The dest gate we are connecting/connected to
     */
    private static void addConnectionToMenu(ConnectionCommand connCommand, BlockingMenu menu, ConnectionNode conn, GateNode srcGate, GateNode destGate) {
        MenuItem mi = menu.addMenuItem(SWT.PUSH);
        // store the connection template in the widget's extra data
        mi.setData(conn);
        String label = NEDTreeUtil.generateNedSource(conn, false).trim();
        mi.setText(label);
        // enable the menu item only if the used gates are unconnected;
        mi.setEnabled(isConnectionValid(connCommand, conn, srcGate, destGate));
    }

    /**
     * Returns whether the connection is valid, that is, the gates we want to connect
     * are unconnected currently
     */
    private static boolean isConnectionValid(ConnectionCommand connCommand, ConnectionNode conn, GateNode srcGate, GateNode destGate) {
        CompoundModuleNodeEx compModule = connCommand.getParentEditPart().getCompoundModuleModel();
        // note that vector gates or any gate on a submodule vector should be treated always unconnected
        // because the user can connect the connection to different instances/indexes of the gate/submodule
        boolean isSrcSideAVector = srcGate.getIsVector() ||
            (srcGate.getParent().getParent() instanceof SubmoduleNodeEx &&
                    !"".equals(((SubmoduleNodeEx)srcGate.getParent().getParent()).getVectorSize()));
        boolean isDestSideAVector = destGate.getIsVector() ||
        (destGate.getParent().getParent() instanceof SubmoduleNodeEx &&
                !"".equals(((SubmoduleNodeEx)destGate.getParent().getParent()).getVectorSize()));

        // if we are inserting a new connection
        if (connCommand.isCreating()) {
            // if there are any connections with the same source or dest gate name, we should return invalid
            if (!compModule.getConnections(conn.getSrcModule(), conn.getSrcGate(), null, null).isEmpty()
                    && !isSrcSideAVector)
                return false;
            if (!compModule.getConnections(null, null, conn.getDestModule(), conn.getDestGate()).isEmpty()
                    && !isDestSideAVector)
                return false;
        }
        // if we are moving the source side connection we should filter only for that side
        if (!isSrcSideAVector && connCommand.isSrcMoving() &&
                !compModule.getConnections(conn.getSrcModule(), conn.getSrcGate(), null, null).isEmpty())
            return false;
        // if we are moving the dest side connection we should filter only for that side
        if (!isDestSideAVector && connCommand.isDestMoving() &&
                !compModule.getConnections(null, null, conn.getDestModule(), conn.getDestGate()).isEmpty())
            return false;
        // the connection can be attached to the gate
        return true;
    }

}
