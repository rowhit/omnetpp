package com.simulcraft.test.gui.access;

import junit.framework.Assert;

import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.Table;
import org.eclipse.swt.widgets.TableColumn;

import com.simulcraft.test.gui.core.InUIThread;

public class TableColumnAccess extends ClickableWidgetAccess
{
	public TableColumnAccess(TableColumn treeColumn) {
		super(treeColumn);
	}

	public TableColumn getTableColumn() {
		return (TableColumn)widget;
	}

    @InUIThread
    public TableAccess getTable() {
        return (TableAccess) createAccess(getTableColumn().getParent());
    }
	
	@InUIThread
	public TableColumnAccess reveal() {
		//TODO horizontally scroll there
		return this;
	}
	
	@Override
	protected Point getAbsolutePointToClick() {
        // center of the header. Note: header is at NEGATIVE table coordinates! (origin is top-left of data area)
	    getTable().assertHeaderVisible();
        Table tree = (Table)getTableColumn().getParent();
        Point point = tree.toDisplay(getX() + getTableColumn().getWidth()/2, -tree.getHeaderHeight()/2);
        Assert.assertTrue("point to click is scrolled out", getTable().getAbsoluteBounds().contains(point));
        Assert.assertTrue("column has zero width, cannot click", getTableColumn().getWidth() > 0);
        return point;
	}

	@Override
	protected Menu getContextMenu() {
		return (Menu)getTableColumn().getParent().getMenu();
	}

	/**
	 * Returns the x coordinate of the left edge of the column, relative to the tree.
	 * Horizontal scrolling of tree is also taken into account.
	 */
	@InUIThread
	public int getX() {
	    Table tree = (Table)getTableColumn().getParent();
	    TableColumn[] columns = tree.getColumns();
	    int[] columnOrder = tree.getColumnOrder();
	    int x = 0;
	    for (int i = 0; i < columns.length; i++) {
	        TableColumn col = columns[columnOrder[i]];
	        if (col == getTableColumn()) {
                int horizontalScrollOffset = tree.getHorizontalBar().getSelection();
                return x - horizontalScrollOffset;
            }
	        x += col.getWidth();
	    }
	    Assert.assertTrue("column is not in the tree", false);
	    return 0;
	}
}
